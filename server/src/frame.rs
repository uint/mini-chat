use borsh::{BorshDeserialize, BorshSerialize};

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
pub struct ClientFrame {
    pub id: u8,
    pub data: ClientFrameType,
}

#[derive(Debug, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
#[repr(u8)]
pub enum ClientFrameType {
    Login(String) = 0,
    Msg(String) = 1,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, BorshSerialize, BorshDeserialize)]
#[repr(u8)]
pub enum ServerFrame {
    Okay(u8) = 0,
    Err(u8, String) = 1,
    Broadcast { sender: String, msg: String } = 2,
    Present(String) = 3,
    Login(String) = 4,
    Logout(String) = 5,
}

#[derive(Debug, thiserror::Error)]
pub enum DecodeError {
    #[error("this server only accepts binary websocket frames")]
    InvalidWebsocketFrame,
    #[error("invalid mini-chat frame")]
    InvalidFrame,
}
