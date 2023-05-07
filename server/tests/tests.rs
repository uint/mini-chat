mod suite;

use server::{frame::ServerFrame, protocol::ws::ws_sink_stream, serve_tcp};
use suite::{run_ws_server, Client};

#[tokio::test]
async fn login_broadcast() {
    let url = run_ws_server().await;
    let mut bob = Client::new("bob", &url).await;
    let jolene = Client::new("jolene", &url).await;

    bob.assert_frame(ServerFrame::Login("jolene".to_string()))
        .await;

    bob.close().await;
    jolene.close().await;
}

#[tokio::test]
async fn whos_present_on_login() {
    let url = run_ws_server().await;
    let bob = Client::new("bob", &url).await;
    let mut jolene = Client::new("jolene", &url).await;
    let mut lurker = Client::new("samantha", &url).await;

    jolene
        .assert_frame(ServerFrame::Present("bob".to_string()))
        .await;
    lurker
        .assert_frame(ServerFrame::Present("bob".to_string()))
        .await;
    lurker
        .assert_frame(ServerFrame::Present("jolene".to_string()))
        .await;

    bob.close().await;
    jolene.close().await;
    lurker.close().await;
}

#[tokio::test]
async fn logout_broadcast() {
    let url = run_ws_server().await;
    let bob = Client::new("bob", &url).await;
    let mut jolene = Client::new("jolene", &url).await;
    let mut lurker = Client::new("samantha", &url).await;

    bob.close().await;
    jolene
        .assert_frame(ServerFrame::Logout("bob".to_string()))
        .await;
    lurker
        .assert_frame(ServerFrame::Logout("bob".to_string()))
        .await;

    jolene.close().await;

    lurker
        .assert_frame(ServerFrame::Logout("jolene".to_string()))
        .await;

    lurker.close().await;
}

#[tokio::test]
async fn msg_broadcast() {
    let url = run_ws_server().await;
    let mut bob = Client::new("bob", &url).await;
    let mut jolene = Client::new("jolene", &url).await;
    let mut lurker = Client::new("samantha", &url).await;

    bob.send_msg("hello there").await;
    // TODO: find a better way to "run all other tokio tasks to completion"
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    jolene.assert_broadcast("bob", "hello there").await;
    lurker.assert_broadcast("bob", "hello there").await;

    jolene.send_msg("general kenobi").await;
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    bob.assert_broadcast("jolene", "general kenobi").await;
    lurker.assert_broadcast("jolene", "general kenobi").await;

    bob.close().await;
    jolene.close().await;
}
