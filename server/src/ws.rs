use borsh::{BorshDeserialize as _, BorshSerialize as _};
use futures_util::{Sink, Stream, StreamExt as _};
use tokio::net::TcpStream;
use tungstenite::Message as WsMessage;

use crate::frame::{ClientFrame, DecodeError, ServerFrame};
use crate::stream::{wrap_client_sink, wrap_client_stream};

impl TryFrom<WsMessage> for ClientFrame {
    type Error = DecodeError;

    fn try_from(msg: WsMessage) -> Result<Self, Self::Error> {
        if let WsMessage::Binary(bytes) = msg {
            Self::try_from_slice(&bytes).map_err(|_| DecodeError::InvalidFrame)
        } else {
            Err(DecodeError::InvalidWebsocketFrame)
        }
    }
}

impl TryFrom<WsMessage> for ServerFrame {
    type Error = DecodeError;

    fn try_from(msg: WsMessage) -> Result<Self, Self::Error> {
        if let WsMessage::Binary(bytes) = msg {
            Self::try_from_slice(&bytes).map_err(|_| DecodeError::InvalidFrame)
        } else {
            Err(DecodeError::InvalidWebsocketFrame)
        }
    }
}

impl TryFrom<ClientFrame> for WsMessage {
    type Error = ();

    fn try_from(frame: ClientFrame) -> Result<Self, Self::Error> {
        Ok(WsMessage::Binary(frame.try_to_vec().map_err(|_| ())?))
    }
}

impl TryFrom<ServerFrame> for WsMessage {
    type Error = ();

    fn try_from(frame: ServerFrame) -> Result<Self, Self::Error> {
        Ok(WsMessage::Binary(frame.try_to_vec().map_err(|_| ())?))
    }
}

impl From<tungstenite::Error> for DecodeError {
    fn from(_value: tungstenite::Error) -> Self {
        DecodeError::InvalidWebsocketFrame
    }
}

pub async fn ws_sink_stream(
    tcp_stream: TcpStream,
) -> (
    impl Sink<ServerFrame, Error = ()>,
    impl Stream<Item = Result<ClientFrame, DecodeError>>,
) {
    let ws_stream = tokio_tungstenite::accept_async(tcp_stream)
        .await
        .expect("Error during the websocket handshake occurred");

    let (sink, stream) = ws_stream.split();
    (wrap_client_sink(sink), wrap_client_stream(stream))
}
