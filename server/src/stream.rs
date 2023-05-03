use std::future;

use futures_util::{Sink, SinkExt, Stream, StreamExt as _};

use crate::frame::{ClientFrame, DecodeError, ServerFrame};

//pub type ClientStream = Box<dyn Stream<Item = Result<ClientFrame, DecodeError>>>;

pub fn wrap_client_stream<S, M, E>(s: S) -> impl Stream<Item = Result<ClientFrame, DecodeError>>
where
    S: Stream<Item = Result<M, E>> + 'static,
    M: TryInto<ClientFrame, Error = DecodeError>,
    E: Into<DecodeError>,
{
    s.map(|item| match item {
        Ok(m) => m.try_into(),
        Err(e) => Err(e.into()),
    })
}

// pub type ClientSink = Box<dyn Sink<ServerFrame, Error = ()>>;

pub fn wrap_client_sink<S, M>(s: S) -> impl Sink<ServerFrame, Error = ()>
where
    S: Sink<M> + 'static,
    M: TryFrom<ServerFrame, Error = ()> + 'static,
{
    s.sink_map_err(|_| ())
        .with(|x: ServerFrame| future::ready(x.try_into()))
}
