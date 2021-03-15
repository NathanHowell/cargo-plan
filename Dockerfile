FROM rust:1-slim-buster@sha256:5bd08f7d6d4ad8d1288abfe384b33980d8a575cd9d5bf8abbba16487f32896e1 AS base
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

FROM debian:buster-slim@sha256:13f0764262a064b2dd9f8a828bbaab29bdb1a1a0ac6adc8610a0a5f37e514955
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
