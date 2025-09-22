# syntax=docker/dockerfile:1.7-labs
FROM rust:1-slim-trixie@sha256:40d4ee109c7e740b3a242f20cc3b5790af9c725828b86a458765f192391a6a4a AS base
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

FROM debian:trixie-slim@sha256:c2880112cc5c61e1200c26f106e4123627b49726375eb5846313da9cca117337
WORKDIR app
### __BEGIN_copy
COPY --from=builder --link /app/target/release ./
### __END_copy
