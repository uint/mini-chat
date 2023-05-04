use server::protocol::ws::ws_sink_stream;

#[tokio::main]
async fn main() -> Result<(), std::io::Error> {
    let addr = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "127.0.0.1:8080".to_string());

    server::serve_tcp(&addr, ws_sink_stream).await
}
