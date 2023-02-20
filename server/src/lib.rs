pub mod frame;

use std::{
    collections::HashMap,
    io::Error as IoError,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use futures_channel::mpsc::{unbounded, UnboundedSender};
use futures_util::{future, pin_mut, stream::TryStreamExt, StreamExt};

use tokio::net::{TcpListener, TcpStream};
use tungstenite::protocol::Message;

use crate::frame::{ClientFrame, ClientFrameType, ServerFrame};

type Tx = UnboundedSender<Message>;
type PeerMap = Arc<Mutex<HashMap<SocketAddr, Tx>>>;

async fn handle_connection(peer_map: PeerMap, raw_stream: TcpStream, addr: SocketAddr) {
    // TODO: abstract away the transport used to send/receive frames (WS in this case)

    println!("Incoming TCP connection from: {}", addr);

    let ws_stream = tokio_tungstenite::accept_async(raw_stream)
        .await
        .expect("Error during the websocket handshake occurred");
    println!("WebSocket connection established: {}", addr);

    // Insert the write part of this peer to the peer map.
    let (tx, rx) = unbounded();
    peer_map.lock().unwrap().insert(addr, tx.clone());

    let (outgoing, mut incoming) = ws_stream.split();

    let handle = if let Some(Ok(msg)) = incoming.next().await {
        if let Ok(ClientFrame {
            id,
            data: ClientFrameType::Login(handle),
        }) = ClientFrame::try_from(msg)
        {
            let accepted_msg = ServerFrame::Okay(id).try_into().unwrap();
            tx.unbounded_send(accepted_msg).unwrap();
            handle
        } else {
            return;
        }
    } else {
        return;
    };

    let handle_incoming = incoming.try_for_each(|msg| {
        if let Ok(ClientFrame { data: request, id }) = ClientFrame::try_from(msg) {
            match request {
                ClientFrameType::Msg(msg) => {
                    // TODO: rewrite this as a separate fn, add error handling
                    // (by sending the error in a frame)

                    let receipt: Message = ServerFrame::Okay(id).try_into().unwrap();
                    tx.unbounded_send(receipt).unwrap();

                    let peers = peer_map.lock().unwrap();

                    // We want to broadcast the message to everyone except ourselves.
                    let broadcast_recipients = peers
                        .iter()
                        .filter(|(peer_addr, _)| peer_addr != &&addr)
                        .map(|(_, ws_sink)| ws_sink);

                    let broadcast_frame = Message::try_from(ServerFrame::Broadcast {
                        sender: handle.clone(),
                        msg,
                    });
                    if let Ok(broadcast_frame) = broadcast_frame {
                        for recp in broadcast_recipients {
                            recp.unbounded_send(broadcast_frame.clone()).unwrap();
                        }
                    }
                }
                _ => {}
            }
        }

        future::ok(())
    });

    let receive_from_others = rx.map(Ok).forward(outgoing);

    pin_mut!(handle_incoming, receive_from_others);
    future::select(handle_incoming, receive_from_others).await;

    println!("{} disconnected", &addr);
    peer_map.lock().unwrap().remove(&addr);
}

pub async fn serve(addr: &str) -> Result<(), IoError> {
    let state = PeerMap::new(Mutex::new(HashMap::new()));

    // Create the event loop and TCP listener we'll accept connections on.
    let try_socket = TcpListener::bind(addr).await;
    let listener = try_socket.expect("Failed to bind");
    println!("Listening on: {}", addr);

    tokio::spawn(async {
        let listener = listener;
        let state = state;

        while let Ok((stream, addr)) = listener.accept().await {
            tokio::spawn(handle_connection(state.clone(), stream, addr));
        }
    });

    Ok(())
}
