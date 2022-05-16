FROM rust:1-slim-buster@sha256:c0c5d46db0e7c3860538840bccce80d3fa43179159f88a8ae786030539cdcb9c AS base
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

FROM debian:buster-slim@sha256:06a7bee0f90b6087f2b239125ef3c75d474e48cc69643d496d0c6e545fd91023
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
