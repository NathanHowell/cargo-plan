FROM rust:1-slim-buster@sha256:6f0e7a8da26122c3aa1c7e5e7ffdd3e38b7b6d98fd0f0d3d1ca040eef9862886 AS base
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

FROM debian:buster-slim@sha256:eecda7f7a3e9cd93d7748c7643628e3a95d622a96b4959b3f1a03e7ac7d37476
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
