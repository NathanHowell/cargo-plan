FROM rust:1-slim-buster@sha256:98c9b1fca0c9a6183369daf9efadb57c634340ae877bb027aeadf72afdd086a3 AS base
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

FROM debian:buster-slim@sha256:c9c3c682452791a9c301786a2beedb20f291e107c1b699fed0d4d145cc247d4f
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
