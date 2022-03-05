FROM rust:1-slim-buster@sha256:9f81be94f30d1d802e7887cc0c25c8417ca4a27c98f5c1afd2e58b64080f8d64 AS base
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

FROM debian:buster-slim@sha256:f6e5cbc7eaaa232ae1db675d83eabfffdabeb9054515c15c2fb510da6bc618a7
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
