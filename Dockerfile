FROM rust:1-slim-buster@sha256:df53d5350e2f161c2e791174b02474429062768fbea91a3cc0164ce1e522b368 AS base
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

FROM debian:buster-slim@sha256:a6bbc75c36b0d9d82ae4b64219b48c3027b7a101e9334b2ffb3bc71dbe94f552
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
