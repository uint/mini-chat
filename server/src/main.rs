use borsh::BorshDeserialize;
use bytes::BytesMut;
use tokio::{
    io::AsyncReadExt as _,
    net::{TcpListener, TcpStream},
};

#[tokio::main]
async fn main() {
    // Bind the listener to the address
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    loop {
        // The second item contains the IP and port of the new connection.
        let (socket, _) = listener.accept().await.unwrap();
        tokio::spawn(async move {
            process(socket).await;
        });
    }
}

async fn process(socket: TcpStream) {
    let conn = Connection::new(socket);
}

pub struct Connection {
    stream: TcpStream,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream,
            buffer: BytesMut::with_capacity(4096),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Hash, thiserror::Error)]
pub enum Error {
    #[error("connection reset by peer")]
    ConnectionReset,
}
