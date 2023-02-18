use std::{
    collections::HashMap,
    io::Error as IoError,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use borsh::{BorshDeserialize, BorshSerialize};
use futures_channel::mpsc::{unbounded, UnboundedSender};
use futures_util::{future, pin_mut, stream::TryStreamExt, SinkExt, StreamExt};

use tokio::net::{TcpListener, TcpStream};
use tungstenite::protocol::Message;

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
        if let Ok(Frame::Login(handle)) = Frame::try_from(msg) {
            handle
        } else {
            tx.unbounded_send(accepted_msg).unwrap();
            return;
        }
    } else {
        return;
    };

    let accepted_msg: Message = Frame::LoginResponse(LoginResponse::Ok).try_into().unwrap();
    tx.unbounded_send(accepted_msg).unwrap();

    let handle_incoming = incoming.try_for_each(|msg| {
        if let Ok(request) = Frame::try_from(msg) {
            match request {
                Frame::Msg(id, msg) => {
                    // TODO: rewrite this as a separate fn, add error handling
                    // (by sending the error in a frame)

                    // println!(
                    //     "Received a message from {}: {}",
                    //     addr,
                    //     msg.to_text().unwrap()
                    // );

                    let receipt: Message = Frame::MsgReceipt(id).try_into().unwrap();
                    tx.unbounded_send(receipt).unwrap();

                    let peers = peer_map.lock().unwrap();

                    // We want to broadcast the message to everyone except ourselves.
                    let broadcast_recipients = peers
                        .iter()
                        .filter(|(peer_addr, _)| peer_addr != &&addr)
                        .map(|(_, ws_sink)| ws_sink);

                    let broadcast_frame = Message::try_from(Frame::Broadcast {
                        sender: Some(handle.clone()),
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

pub struct ClientFrame(u8, Frame);

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
pub enum Frame {
    Login(String),
    LoginResponse(LoginResponse),
    Msg(String),
    MsgReceipt(u8),
    Broadcast { sender: Option<String>, msg: String },
}

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
pub enum LoginResponse {
    Ok,
    Taken,
    Invalid,
}

#[derive(Debug, thiserror::Error)]
pub enum DecodeError {
    #[error("this server only accepts binary websocket frames")]
    InvalidWebsocketFrame,
    #[error("invalid mini-chat frame")]
    InvalidFrame,
}

impl TryFrom<Message> for Frame {
    type Error = DecodeError;

    fn try_from(msg: Message) -> Result<Self, Self::Error> {
        if let Message::Binary(bytes) = msg {
            Frame::try_from_slice(&bytes).map_err(|_| DecodeError::InvalidFrame)
        } else {
            Err(DecodeError::InvalidWebsocketFrame)
        }
    }
}

impl TryFrom<Frame> for Message {
    type Error = ();

    fn try_from(frame: Frame) -> Result<Self, Self::Error> {
        Ok(Message::Binary(frame.try_to_vec().map_err(|_| ())?))
    }
}
