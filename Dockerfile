FROM rust:1-slim-buster@sha256:559a58f7f85df91fed6f83fe0bce8a8352dc2dd980b0cff1c4787fee88618334 AS base
WORKDIR app
### __BEGIN_install
RUN cargo install --git https://github.com/NathanHowell/cargo-plan --branch master
### __END_install

FROM base AS planner
COPY . .
RUN cargo plan create -- --all-features --locked

FROM base AS builder
COPY --from=planner /app/cargo-plan.tar cargo-plan.tar
RUN cargo plan build -- --release --frozen
COPY . .
RUN cargo build --release --bins --frozen

FROM debian:buster-slim@sha256:b92194336992198b8d97d5f08b94f28459b6cb7146b4ea549c0fd45351ed7718
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
