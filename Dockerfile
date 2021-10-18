FROM rust:1-slim-buster@sha256:b8641d3a2411f34b52eb7d69488cd42fc2eebc33a085124b64c465847f457c61 AS base
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

FROM debian:buster-slim@sha256:a364ab17ed74911bf0913ce1099054e9bcbabc80bf0faae7dac4d3470b472e24
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
