FROM rust:1-slim-buster@sha256:aca8bfd661e34b0a5cc4e0c674b1ebeb5849116ebe5bbe3bcd9e39ea16510921 AS base
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

FROM debian:buster-slim@sha256:c8152821b158dd171b4acf92afb0a58fc2faa179a7e0af8ace358fbe1668e99d
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
