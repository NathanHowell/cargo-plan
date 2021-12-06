FROM rust:1-slim-buster@sha256:8f13b18bbb0c8d21b5e6d9a0cec713ca683686ea49c0d9486e5d82515378fee2 AS base
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

FROM debian:buster-slim@sha256:c72b2ae10bbe698b3279dcc63def01660a4431072e8d71b00f378b37b3eeda30
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
