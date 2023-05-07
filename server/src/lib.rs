pub mod frame;
pub mod protocol;
mod state;
mod stream;

use std::{
    collections::HashMap,
    io::Error as IoError,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use frame::DecodeError;
use futures_channel::mpsc::{unbounded, UnboundedSender};
use futures_util::{future, pin_mut, Future, Sink, SinkExt, Stream, StreamExt};

use tokio::net::{TcpListener, TcpStream};

use crate::frame::{ClientFrame, ClientFrameType, ServerFrame};

type Tx = UnboundedSender<ServerFrame>;
type PeerMap = Arc<Mutex<HashMap<SocketAddr, Tx>>>;

async fn handle_connection<SNK, STR>(
    peer_map: PeerMap,
    mut sink: SNK,
    mut stream: STR,
    addr: SocketAddr,
) where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()> + Unpin,
{
    // Insert the write part of this peer to the peer map.
    let (tx, rx) = unbounded();
    peer_map.lock().unwrap().insert(addr, tx.clone());

    let handle = match handle_login(&peer_map, &mut sink, &mut stream).await {
        Ok(handle) => handle,
        _ => return,
    };

    let handle_frames = handle_chat_msgs(&peer_map, tx.clone(), &mut stream, &addr, &handle);
    let receive_from_others = rx.map(Ok).forward(sink);

    pin_mut!(handle_frames, receive_from_others);
    future::select(handle_frames, receive_from_others).await;

    println!("{} disconnected", &addr);
    peer_map.lock().unwrap().remove(&addr);
}

async fn handle_login<SNK, STR>(
    _peer_map: &PeerMap,
    sink: &mut SNK,
    stream: &mut STR,
) -> Result<String, ()>
where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()> + Unpin,
{
    if let Some(Ok(msg)) = stream.next().await {
        if let Ok(ClientFrame {
            id,
            data: ClientFrameType::Login(handle),
        }) = ClientFrame::try_from(msg)
        {
            let accepted_msg = ServerFrame::Okay(id);
            sink.send(accepted_msg).await?;
            Ok(handle)
        } else {
            Err(())
        }
    } else {
        Err(())
    }
}

async fn handle_chat_msgs<STR>(
    peer_map: &PeerMap,
    tx: Tx,
    stream: &mut STR,
    addr: &SocketAddr,
    handle: &str,
) where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
{
    while let Some(frame) = stream.next().await {
        if let Ok(ClientFrame { data: request, id }) = frame {
            match request {
                ClientFrameType::Msg(msg) => {
                    let receipt = ServerFrame::Okay(id);
                    if let Err(_) = tx.unbounded_send(receipt) {
                        return;
                    }

                    let peers = peer_map.lock().unwrap();

                    // We want to broadcast the message to everyone except ourselves.
                    let broadcast_recipients = peers
                        .iter()
                        .filter(|(peer_addr, _)| peer_addr != &addr)
                        .map(|(_, ws_sink)| ws_sink);

                    let broadcast_frame = ServerFrame::Broadcast {
                        sender: handle.to_string(),
                        msg,
                    };

                    for recp in broadcast_recipients {
                        recp.unbounded_send(broadcast_frame.clone()).unwrap();
                    }
                }
                _ => {}
            }
        }
    }
}

pub async fn serve_tcp<F, FUT, SNK, STR>(addr: &str, stream_builder: F) -> Result<(), IoError>
where
    F: Fn(TcpStream) -> FUT + Send + 'static,
    FUT: Future<Output = (SNK, STR)> + Send,
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Send + Unpin + 'static,
    SNK: Sink<ServerFrame, Error = ()> + Send + Unpin + 'static,
{
    let state = PeerMap::new(Mutex::new(HashMap::new()));

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
