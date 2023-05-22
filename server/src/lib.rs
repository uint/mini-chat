pub mod frame;
pub mod protocol;
mod stream;

use std::{collections::HashMap, io::Error as IoError, net::SocketAddr, sync::Arc};

use frame::DecodeError;
use futures_channel::mpsc::{unbounded, UnboundedSender};
use futures_util::future::Either;
use futures_util::{future, pin_mut, Future, Sink, SinkExt, Stream, StreamExt};

use crate::frame::{ClientFrame, ClientFrameType, ServerFrame};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::RwLock;

type Tx = UnboundedSender<ServerFrame>;
type PeerMap = Arc<RwLock<HashMap<String, Tx>>>;

async fn handle_connection<SNK, STR>(
    peer_map: PeerMap,
    mut sink: SNK,
    mut stream: STR,
    addr: SocketAddr,
) where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()> + Unpin,
{
    while let Ok(handle) = handle_login(&peer_map, &mut sink, &mut stream).await {
        // Insert the write part of this peer to the peer map.
        let (tx, rx) = unbounded();

        peer_map.write().await.insert(handle.clone(), tx.clone());

        let handle_frames = handle_chat_msgs(&peer_map, tx.clone(), &mut stream, &handle);
        let receive_from_others = rx.map(Ok).forward(&mut sink);

        pin_mut!(handle_frames, receive_from_others);
        let x = future::select(handle_frames, receive_from_others).await;
        if let Either::Left((Some(id), _)) = x {
            let _ = sink.send(ServerFrame::Okay(id)).await;
        }

        // could be smarter to hold a handle here that removes from the peer map on drop
        peer_map.write().await.remove(&handle);
        for peer in peer_map.read().await.values() {
            let _ = peer.unbounded_send(ServerFrame::Logout(handle.clone()));
        }
        println!("{} logged out", &handle);
    }

    println!("{} disconnected", &addr);
}

async fn handle_login<SNK, STR>(
    peer_map: &PeerMap,
    sink: &mut SNK,
    stream: &mut STR,
) -> Result<String, ()>
where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()> + Unpin,
{
    if let Some(Ok(ClientFrame {
        id,
        data: ClientFrameType::Login(handle),
    })) = stream.next().await
    {
        if peer_map.read().await.contains_key(&handle) {
            sink.send(ServerFrame::Err(id, "handle taken".to_string()))
                .await?;
            return Err(());
        }
        sink.send(ServerFrame::Okay(id)).await?;

        for (peer_handle, tx) in peer_map.read().await.iter() {
            let _ = tx.unbounded_send(ServerFrame::Login(handle.clone()));
            let _ = sink
                .send(ServerFrame::Present(peer_handle.to_string()))
                .await;
        }

        println!("{} logged in", &handle);

        Ok(handle)
    } else {
        Err(())
    }
}

async fn handle_chat_msgs<STR>(
    peer_map: &PeerMap,
    tx: Tx,
    stream: &mut STR,
    handle: &str,
) -> Option<u8>
where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
{
    while let Some(frame) = stream.next().await {
        if let Ok(ClientFrame { data: request, id }) = frame {
            match request {
                ClientFrameType::Msg(msg) => {
                    let receipt = ServerFrame::Okay(id);

                    let _ = tx.unbounded_send(receipt);

                    let peers = peer_map.read().await;

                    let broadcast_recipients = peers
                        .iter()
                        .filter(|(peer_handle, _)| peer_handle.as_str() != handle)
                        .map(|(_, ws_sink)| ws_sink);

                    let broadcast_frame = ServerFrame::Broadcast {
                        sender: handle.to_string(),
                        msg,
                    };

                    for recp in broadcast_recipients {
                        recp.unbounded_send(broadcast_frame.clone()).unwrap();
                    }
                }
                ClientFrameType::Logout => {
                    return Some(id);
                }
                _ => {}
            }
        }
    }

    None
}

/// The `stream_builder` callable is meant to split the [`TcpStream`] and decorate both the
/// stream and sink. It can e.g. implement WebSocket as a transport for mini-chat frames.
///
/// This design should make it easier to, in the future, add other transports like raw TCP.
pub async fn serve_tcp<F, FUT, SNK, STR>(addr: &str, stream_builder: F) -> Result<(), IoError>
where
    F: Fn(TcpStream) -> FUT + Send + 'static,
    FUT: Future<Output = Result<(SNK, STR), String>> + Send,
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Send + Unpin + 'static,
    SNK: Sink<ServerFrame, Error = ()> + Send + Unpin + 'static,
{
    let state = PeerMap::new(RwLock::new(HashMap::new()));

    let try_socket = TcpListener::bind(addr).await;
    let listener = try_socket.expect("Failed to bind");
    println!("Listening on: {}", addr);

    let listener = listener;
    let state = state;

    while let Ok((tcp_stream, addr)) = listener.accept().await {
        if let Ok((sink, stream)) = stream_builder(tcp_stream).await {
            tokio::spawn(handle_connection(state.clone(), sink, stream, addr));
        }
    }

    Ok(())
}
