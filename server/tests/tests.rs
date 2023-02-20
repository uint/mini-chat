mod suite;

use server::serve;

use suite::Client;

#[tokio::test]
async fn broadcast() {
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
