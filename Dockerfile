FROM rust:1-slim-buster@sha256:7da4fbd2dc7176746e8e5c371aeb0bbe742598c4906fa48cb2d87a4b89d50357 AS base
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

FROM debian:buster-slim@sha256:557ee531b81ce380d012d83b7bb56211572e5d6088d3e21a3caef7d7ed7f718b
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
