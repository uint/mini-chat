# Build Stage
FROM rust:1.69.0 AS builder
WORKDIR /usr/src/
RUN rustup target add x86_64-unknown-linux-musl

RUN USER=root cargo new mini-chat
WORKDIR /usr/src/mini-chat
COPY server/Cargo.toml Cargo.lock ./
RUN cargo build --release

COPY server/src ./src
RUN cargo install --target x86_64-unknown-linux-musl --path .

# Bundle Stage
FROM scratch

COPY --from=builder /usr/local/cargo/bin/mini-chat .
USER 1000

EXPOSE 3333

CMD ["./mini-chat", "0.0.0.0:3333"]
