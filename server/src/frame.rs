use borsh::{BorshDeserialize, BorshSerialize};
use tungstenite::Message;

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
pub struct ClientFrame {
    pub id: u8,
    pub data: ClientFrameType,
}

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
pub enum ClientFrameType {
    Login(String),
    Msg(String),
}

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
pub enum ServerFrame {
    Okay(u8),
    Err(u8, String),
    Broadcast { sender: String, msg: String },
    Present(String),
    Login(String),
    Logout(String),
}

#[derive(Debug, thiserror::Error)]
pub enum DecodeError {
    #[error("this server only accepts binary websocket frames")]
    InvalidWebsocketFrame,
    #[error("invalid mini-chat frame")]
    InvalidFrame,
}

impl TryFrom<Message> for ClientFrame {
    type Error = DecodeError;

    fn try_from(msg: Message) -> Result<Self, Self::Error> {
        if let Message::Binary(bytes) = msg {
            Self::try_from_slice(&bytes).map_err(|_| DecodeError::InvalidFrame)
        } else {
            Err(DecodeError::InvalidWebsocketFrame)
        }
    }
}

impl TryFrom<Message> for ServerFrame {
    type Error = DecodeError;

    fn try_from(msg: Message) -> Result<Self, Self::Error> {
        if let Message::Binary(bytes) = msg {
            Self::try_from_slice(&bytes).map_err(|_| DecodeError::InvalidFrame)
        } else {
            Err(DecodeError::InvalidWebsocketFrame)
        }
    }
}

impl TryFrom<ClientFrame> for Message {
    type Error = ();

    fn try_from(frame: ClientFrame) -> Result<Self, Self::Error> {
        Ok(Message::Binary(frame.try_to_vec().map_err(|_| ())?))
    }
}

impl TryFrom<ServerFrame> for Message {
    type Error = ();

    fn try_from(frame: ServerFrame) -> Result<Self, Self::Error> {
        Ok(Message::Binary(frame.try_to_vec().map_err(|_| ())?))
    }
}
