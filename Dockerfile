FROM rust:1-slim-buster@sha256:b0b99a29bfa1a80a95051b7608ac44a0e4cbe20bdba466e43fd52492fb334eaf AS base
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

FROM debian:buster-slim@sha256:1be41347adaee8303bf12114b9edf4af0b35a5e1d9756b3ddad59856eaa31ea7
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
