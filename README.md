# mini-chat

Just a little toy project, mostly to learn Flutter and get a refresher in async Rust. One stone, two birds!

<img src="/.assets/demo.gif" width="478" height="195"/>

# Running the server

Right now, you can run the server with:

```sh
cargo run
```

You could also use docker.

```sh
docker build . -t mini-chat
docker run -p 3333:3333 mini-chat
```

# Running the client

```sh
cd client
flutter run
```

By default, the client will be built with a mock backend. If you have the server up, you can instead connect to it:

```sh
flutter run --dart-define MC_WS_URL=ws://127.0.0.1:3333
```
