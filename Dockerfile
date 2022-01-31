FROM rust:1-slim-buster@sha256:13f7d549ad64c8171a08b02cf69b5268cec17c5fab9bf3ee93da3f4b4357f628 AS base
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
