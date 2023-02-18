use futures_util::{
    stream::{SplitSink, SplitStream},
    SinkExt, StreamExt,
};
use server::{serve, Frame, LoginResponse};
use tokio::net::TcpStream;
use tokio_tungstenite::{
    connect_async, tungstenite::protocol::Message, MaybeTlsStream, WebSocketStream,
};

type Stream = WebSocketStream<MaybeTlsStream<TcpStream>>;

struct Client {
    write: SplitSink<Stream, Message>,
    read: SplitStream<Stream>,
    msg_count: u32,
}

impl Client {
    async fn new(handle: &str, url: &str) -> Self {
        let (ws_stream, _) = connect_async(url).await.expect("Failed to connect");
        println!("WebSocket handshake has been successfully completed");

        let (write, read) = ws_stream.split();

        let mut client = Self {
            write,
            read,
            msg_count: 0,
        };

        client.send_frame(Frame::Login(handle.to_string())).await;
        client
            .assert_frame(Frame::LoginResponse(LoginResponse::Ok))
            .await;

        client
    }

    async fn send_frame(&mut self, frame: Frame) {
        self.write.send(frame.try_into().unwrap()).await.unwrap();
    }

    async fn send_msg(&mut self, msg: &str) {
        self.send_frame(Frame::Msg(self.msg_count, msg.to_string()))
            .await;
        self.assert_frame(Frame::MsgReceipt(self.msg_count)).await;
        self.msg_count += 1;
    }

    async fn assert_frame(&mut self, exp_frame: Frame) {
        if let Some(msg) = self.read.next().await {
            let frame = msg.unwrap().try_into().unwrap();
            assert_eq!(exp_frame, frame);
        } else {
            panic!("no data received");
        }
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

    async fn close(mut self) {
        self.write.close().await.unwrap();
    }
}

#[tokio::test]
async fn test() {
    serve("127.0.0.1:3746").await.unwrap();
    let mut bob = Client::new("bob", "ws://127.0.0.1:3746").await;
    let mut jolene = Client::new("jolene", "ws://127.0.0.1:3746").await;
    let mut lurker = Client::new("samantha", "ws://127.0.0.1:3746").await;

    bob.send_msg("hello there").await;
    jolene.assert_broadcast("bob", "hello there").await;
    lurker.assert_broadcast("bob", "hello there").await;

    jolene.send_msg("general kenobi").await;
    bob.assert_broadcast("jolene", "general kenobi").await;
    lurker.assert_broadcast("jolene", "general kenobi").await;

    bob.close().await;
    jolene.close().await;
}
