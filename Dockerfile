FROM rust:1-slim-buster@sha256:77c9eda3480331493981ecd46b1eedbf78b337b236cdefea559d4861684322a1 AS base
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

FROM debian:buster-slim@sha256:e61cffb42ef0dbb31832d4543d6998ab9125210d0136bc0aed65cc753cee9125
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
