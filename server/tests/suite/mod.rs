use std::time::Duration;

use futures_util::{stream::ReadyChunks, SinkExt, StreamExt};
use server::frame::{ClientFrame, ClientFrameType, ServerFrame};
use tokio::net::TcpStream;
use tokio::select;
use tokio_tungstenite::{connect_async, MaybeTlsStream, WebSocketStream};

type Stream = WebSocketStream<MaybeTlsStream<TcpStream>>;

pub struct Client {
    stream: ReadyChunks<Stream>,
    incoming: Vec<ServerFrame>,
    msg_count: u8,
}

impl Client {
    pub async fn new(handle: &str, url: &str) -> Self {
        let (stream, _) = connect_async(url).await.expect("Failed to connect");

        let mut client = Self {
            stream: stream.ready_chunks(100),
            incoming: Vec::new(),
            msg_count: 0,
        };

        let login = client
            .send_frame(ClientFrameType::Login(handle.to_string()))
            .await;
        client.assert_frame(ServerFrame::Okay(login)).await;

        client
    }

    pub async fn send_frame(&mut self, frame: ClientFrameType) -> u8 {
        let id = self.msg_count;
        self.stream
            .send(ClientFrame { id, data: frame }.try_into().unwrap())
            .await
            .unwrap();
        self.msg_count += 1;
        id
    }

    pub async fn send_msg(&mut self, msg: &str) {
        let id = self.send_frame(ClientFrameType::Msg(msg.to_string())).await;
        self.assert_frame(ServerFrame::Okay(id)).await;
    }

    pub async fn assert_frame(&mut self, exp_frame: ServerFrame) {
        self.collect_incoming().await;
        if !self.incoming.iter().find(|f| f == &&exp_frame).is_some() {
            panic!("frame not received: {:?}", exp_frame);
        }
    }

    pub async fn assert_broadcast(&mut self, exp_sender: &str, exp_msg: &str) {
        self.assert_frame(ServerFrame::Broadcast {
            sender: exp_sender.to_string(),
            msg: exp_msg.to_string(),
        })
        .await;
    }

    pub async fn close(mut self) {
        self.stream.close().await.unwrap();
    }

    /// Collect ready incoming messages from the server and store them
    /// for later inspection.
    async fn collect_incoming(&mut self) {
        // Time out if waiting for ready messages for more than 50 miliseconds,
        // since that probably means nothing is coming.
        //
        // There's probably a better way to do this by digging into async internals.
        select!(Some(v) = self.stream.next() => self.incoming
                .extend(v.into_iter().map(|res| res.unwrap().try_into().unwrap())),
                _ = tokio::time::sleep(Duration::from_millis(50)) => {});
    }
}
