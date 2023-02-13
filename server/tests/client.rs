use futures_util::{
    stream::{SplitSink, SplitStream},
    SinkExt, StreamExt,
};
use server::{serve, Frame};
use tokio::net::TcpStream;
use tokio_tungstenite::{
    connect_async, tungstenite::protocol::Message, MaybeTlsStream, WebSocketStream,
};

type Stream = WebSocketStream<MaybeTlsStream<TcpStream>>;

struct Client {
    write: SplitSink<Stream, Message>,
    read: SplitStream<Stream>,
}

impl Client {
    async fn new(url: &str) -> Self {
        let (ws_stream, _) = connect_async(url).await.expect("Failed to connect");
        println!("WebSocket handshake has been successfully completed");

        let (write, read) = ws_stream.split();

        Self { write, read }
    }

    async fn send_frame(&mut self, frame: Frame) {
        self.write.send(frame.try_into().unwrap()).await.unwrap();
    }

    async fn send_msg(&mut self, msg: &str) {
        self.send_frame(Frame::Msg(msg.to_string())).await;
    }

    async fn assert_broadcast(&mut self, exp_sender: impl Into<Option<&str>>, exp_msg: &str) {
        let exp_sender = exp_sender.into().map(ToString::to_string);
        if let Some(msg) = self.read.next().await {
            let msg = msg.unwrap();
            if let Frame::Broadcast { sender, msg } = msg.try_into().unwrap() {
                assert_eq!(exp_sender, sender);
                assert_eq!(exp_msg, msg);
            } else {
                panic!("invalid message");
            }
        } else {
            panic!("no data received");
        }
    }

    /// Attempt to close the connection.
    ///
    /// Returns `true` if closed cleanly (without errors).
    async fn close(mut self) -> bool {
        self.write.close().await.is_ok()
    }
}

#[tokio::test]
async fn test() {
    serve("127.0.0.1:3746").await.unwrap();
    let mut bob = Client::new("ws://127.0.0.1:3746").await;
    let mut jolene = Client::new("ws://127.0.0.1:3746").await;

    bob.send_msg("hello there").await;
    bob.assert_broadcast(None, "hello there").await;
    jolene.assert_broadcast(None, "hello there").await;

    jolene.send_msg("general kenobi").await;
    bob.assert_broadcast(None, "general kenobi").await;
    jolene.assert_broadcast(None, "general kenobi").await;

    bob.close().await;
    jolene.close().await;
}
