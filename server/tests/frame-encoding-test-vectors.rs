// This doesn't exist for testing any functionality, but just to keep around
// some test vectors and make sure they're up to date.
// They'll probably come in handy when implementing the client
// later.

#[test]
fn server_frames() {
    use borsh::BorshSerialize as _;
    use minichat_server::frame::ServerFrame;

    let frame = ServerFrame::Okay(2);
    assert_eq!(frame.try_to_vec().unwrap(), [0, 2]);

    let frame = ServerFrame::Err(2, "a".to_string());
    assert_eq!(frame.try_to_vec().unwrap(), [1, 2, 1, 0, 0, 0, 97]);

    let frame = ServerFrame::Broadcast {
        sender: "bob".to_string(),
        msg: "hi".to_string(),
    };
    assert_eq!(
        frame.try_to_vec().unwrap(),
        [2, 3, 0, 0, 0, 98, 111, 98, 2, 0, 0, 0, 104, 105]
    );

    let frame = ServerFrame::Present("a".to_string());
    assert_eq!(frame.try_to_vec().unwrap(), [3, 1, 0, 0, 0, 97]);
}
