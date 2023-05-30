use std::net::SocketAddr;

use futures_util::future::Either;
use futures_util::{future, pin_mut, Sink, SinkExt, Stream, StreamExt};

use crate::context::{Context, UserGuard, UserPool};
use crate::frame::DecodeError;
use crate::frame::{ClientFrame, ClientFrameType, ServerFrame};

pub async fn handle_connection<SNK, STR>(
    ctx: Context,
    mut sink: SNK,
    mut stream: STR,
    addr: SocketAddr,
) where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()> + Unpin,
{
    println!("{} connected", &addr);

    fn on_logout(handle: &str, pool: &UserPool) {
        pool.broadcast(ServerFrame::Logout(handle.to_string()));
        println!("{} logged out", handle);
    }

    while let Ok(mut user) = handle_login(&ctx, &mut sink, &mut stream, on_logout).await {
        let rx = user.take_rx().unwrap();
        let handle_frames = handle_chat_msgs(&ctx, user, &mut stream);
        let receive_from_others = rx.map(Ok).forward(&mut sink);

        pin_mut!(handle_frames, receive_from_others);
        let x = future::select(handle_frames, receive_from_others).await;
        if let Either::Left((Some(id), _)) = x {
            let _ = sink.send(ServerFrame::Okay(id)).await;
        }
    }

    println!("{} disconnected", &addr);
}

async fn handle_login<'c, F, SNK, STR>(
    ctx: &'c Context,
    sink: &mut SNK,
    stream: &mut STR,
    on_logout: F,
) -> Result<UserGuard<'c, F>, ()>
where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    SNK: Sink<ServerFrame, Error = ()> + Unpin,
    F: Fn(&str, &UserPool),
{
    if let Some(Ok(ClientFrame {
        id,
        data: ClientFrameType::Login(handle),
    })) = stream.next().await
    {
        match ctx.users().register_user_with_callback(handle, on_logout) {
            Some(user) => {
                sink.send(ServerFrame::Okay(id)).await?;

                ctx.users()
                    .broadcast_except(user.handle(), ServerFrame::Login(user.handle().to_string()));

                for peer_handle in ctx.users().users() {
                    let _ = sink
                        .send(ServerFrame::Present(peer_handle.to_string()))
                        .await;
                }

                println!("{} logged in", user.handle());

                Ok(user)
            }
            None => {
                sink.send(ServerFrame::Err(id, "handle taken".to_string()))
                    .await?;
                Err(())
            }
        }
    } else {
        Err(())
    }
}

async fn handle_chat_msgs<STR, F>(
    cx: &Context,
    user: UserGuard<'_, F>,
    stream: &mut STR,
) -> Option<u8>
where
    STR: Stream<Item = Result<ClientFrame, DecodeError>> + Unpin,
    F: Fn(&str, &UserPool),
{
    while let Some(frame) = stream.next().await {
        if let Ok(ClientFrame { data: request, id }) = frame {
            match request {
                ClientFrameType::Msg(msg) => {
                    let receipt = ServerFrame::Okay(id);

                    let _ = user.send(receipt);

                    cx.users().broadcast_except(
                        user.handle(),
                        ServerFrame::Broadcast {
                            sender: user.handle().to_string(),
                            msg,
                        },
                    );
                }
                ClientFrameType::Logout => {
                    return Some(id);
                }
                _ => {}
            }
        }
    }

    None
}
