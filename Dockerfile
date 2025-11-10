# syntax=docker/dockerfile:1.7-labs
FROM rust:1-slim-trixie@sha256:d9ba8014603166915f7e0fcaa9af09df2a1fc30547e75a72c1d34165139f036a AS base
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

FROM debian:trixie-slim@sha256:66b37a5078a77098bfc80175fb5eb881a3196809242fd295b25502854e12cbec
WORKDIR app
### __BEGIN_copy
COPY --from=builder --link /app/target/release ./
### __END_copy
