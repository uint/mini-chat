mod context;
pub mod frame;
mod logic;
pub mod protocol;
mod stream;

use std::io::Error as IoError;

use futures_util::{Future, Sink, Stream};
use tokio::net::{TcpListener, TcpStream};

use crate::context::Context;
use crate::frame::DecodeError;
use crate::frame::{ClientFrame, ServerFrame};
use crate::logic::handle_connection;

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
    // if we ever serve on multiple ports (e.g. different transports), this context will need to be
    // created outside this function and passed by parameter so that it can be shared
    let ctx = Context::new();

    let try_socket = TcpListener::bind(addr).await;
    let listener = try_socket.expect("Failed to bind");
    println!("Listening on: {}", addr);

    let listener = listener;

    while let Ok((tcp_stream, addr)) = listener.accept().await {
        if let Ok((sink, stream)) = stream_builder(tcp_stream).await {
            tokio::spawn(handle_connection(ctx.clone(), sink, stream, addr));
        }
    }

    Ok(())
}
