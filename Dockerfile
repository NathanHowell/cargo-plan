# syntax=docker/dockerfile:1.7-labs
FROM rust:1-slim-trixie@sha256:5218a2b4b4cb172f26503ac2b2de8e5ffd629ae1c0d885aff2cbe97fd4d1a409 AS base
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

FROM debian:trixie-slim@sha256:a347fd7510ee31a84387619a492ad6c8eb0af2f2682b916ff3e643eb076f925a
WORKDIR app
### __BEGIN_copy
COPY --from=builder --link /app/target/release ./
### __END_copy
