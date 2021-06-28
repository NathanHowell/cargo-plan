FROM rust:1-slim-buster@sha256:dc1b6f724fa9a904830b3dceb3734bc437dbf969962f6795aa8c67fd0b34712c AS base
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

FROM debian:buster-slim@sha256:c6e92d5b7730fdfc2753c4cce68c90d6c86a6a3391955549f9fe8ad6ce619ce0
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
