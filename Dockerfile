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

FROM debian:buster-slim@sha256:fac2ae50be3f4e0901582e5c0ef00d06b1f599315a2077ab5b8ea7e304ddbee4
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
