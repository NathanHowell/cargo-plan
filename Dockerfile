# syntax=docker/dockerfile:1.7-labs
FROM rust:1-slim-trixie@sha256:f7bf1c266d9e48c8d724733fd97ba60464c44b743eb4f46f935577d3242d81d0 AS base
WORKDIR app
### __BEGIN_install
RUN cargo install --git https://github.com/NathanHowell/cargo-plan --branch master
### __END_install

FROM base AS planner
COPY --parents **/lib.rs **/main.rs **/Cargo.toml Cargo.lock ./
RUN cargo plan create -- --all-features --locked

FROM base AS builder
COPY --from=planner --link /app/cargo-plan.tar cargo-plan.tar
RUN cargo plan build -- --release --frozen
COPY . .
RUN cargo build --release --bins --frozen

FROM debian:trixie-slim@sha256:26f98ccd92fd0a44d6928ce8ff8f4921b4d2f535bfa07555ee5d18f61429cf0c
WORKDIR app
### __BEGIN_copy
COPY --from=builder --link /app/target/release ./
### __END_copy
