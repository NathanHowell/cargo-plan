FROM rust:1-slim-buster@sha256:da66962a6c5b9cae84a6e3e9ea67da5507b91ec0b4604016e07f5077286b1b2e AS base
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

FROM debian:buster-slim@sha256:702bc27ef4be73f9c1d73c1a2bc58987c59b6fc8e8e04f46c166849817ce95dc
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
