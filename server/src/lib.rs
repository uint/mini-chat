pub mod frame;
mod state;
mod stream;
pub mod ws;

use std::{
    collections::HashMap,
    io::Error as IoError,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use frame::DecodeError;
use futures_channel::mpsc::{unbounded, UnboundedSender};
use futures_util::{future, pin_mut, stream::TryStreamExt, Future, Sink, Stream, StreamExt};

use tokio::net::{TcpListener, TcpStream};

use crate::frame::{ClientFrame, ClientFrameType, ServerFrame};

type Tx = UnboundedSender<ServerFrame>;
type PeerMap = Arc<Mutex<HashMap<SocketAddr, Tx>>>;

async fn handle_connection<SNK, STR>(
    peer_map: PeerMap,
    sink: SNK,
    mut stream: STR,
    addr: SocketAddr,
) where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()>,
{
    // TODO: abstract away the transport used to send/receive frames (WS in this case)

    // Insert the write part of this peer to the peer map.
    let (tx, rx) = unbounded();
    peer_map.lock().unwrap().insert(addr, tx.clone());

    let handle = if let Some(Ok(msg)) = stream.next().await {
        if let Ok(ClientFrame {
            id,
            data: ClientFrameType::Login(handle),
        }) = ClientFrame::try_from(msg)
        {
            let accepted_msg = ServerFrame::Okay(id);
            tx.unbounded_send(accepted_msg).unwrap();
            handle
        } else {
            return;
        }
    } else {
        return;
    };

    let handle_incoming = stream.try_for_each(|msg| {
        if let Ok(ClientFrame { data: request, id }) = ClientFrame::try_from(msg) {
            match request {
                ClientFrameType::Msg(msg) => {
                    let receipt = ServerFrame::Okay(id);
                    tx.unbounded_send(receipt).unwrap();

                    let peers = peer_map.lock().unwrap();

                    // We want to broadcast the message to everyone except ourselves.
                    let broadcast_recipients = peers
                        .iter()
                        .filter(|(peer_addr, _)| peer_addr != &&addr)
                        .map(|(_, ws_sink)| ws_sink);

                    let broadcast_frame = ServerFrame::Broadcast {
                        sender: handle.clone(),
                        msg,
                    };

                    for recp in broadcast_recipients {
                        recp.unbounded_send(broadcast_frame.clone()).unwrap();
                    }
                }
                _ => {}
            }
        }

        future::ok(())
    });

    let receive_from_others = rx.map(Ok).forward(sink);

    pin_mut!(handle_incoming, receive_from_others);
    future::select(handle_incoming, receive_from_others).await;

    println!("{} disconnected", &addr);
    peer_map.lock().unwrap().remove(&addr);
}

pub async fn serve_tcp<F, FUT, SNK, STR>(addr: &str, stream_builder: F) -> Result<(), IoError>
where
    F: Fn(TcpStream) -> FUT + Send + 'static,
    FUT: Future<Output = (SNK, STR)> + Send,
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Send + Unpin + 'static,
    SNK: Sink<ServerFrame, Error = ()> + Send + 'static,
{
    let state = PeerMap::new(Mutex::new(HashMap::new()));

    // Create the event loop and TCP listener we'll accept connections on.
    let try_socket = TcpListener::bind(addr).await;
    let listener = try_socket.expect("Failed to bind");
    println!("Listening on: {}", addr);

    tokio::spawn(async move {
        let listener = listener;
        let state = state;

        while let Ok((tcp_stream, addr)) = listener.accept().await {
            let fut = stream_builder(tcp_stream);
            let (sink, stream) = fut.await;

            tokio::spawn(handle_connection(state.clone(), sink, stream, addr));
        }
    });

    Ok(())
}
