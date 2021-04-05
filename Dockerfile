FROM rust:1-slim-buster@sha256:16068ef12ce4ba68ef9edc517d5a11a0ec60e35fc53c25620091b1b706d83b91 AS base
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

FROM debian:buster-slim@sha256:1e61bfbfcef8f9690a0641e4dbb0eae46e2ad00eff065bd586a1d58967ee4b66
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
