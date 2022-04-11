FROM rust:1-slim-buster@sha256:c0f26a0b299a8a74cd87be0b4bd291d55aa292198bab1bafd906edd8665edb82 AS base
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

FROM debian:buster-slim@sha256:c2f9136f97c36f57f0cc032abcaffc15de728c386c08ad130f713336972540b5
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
