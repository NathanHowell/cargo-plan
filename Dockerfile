# syntax=docker/dockerfile:1.7-labs
FROM rust:1-slim-trixie@sha256:26318aeddc7e7335b55ab32f943ec2d400bcc024649f8dbdee569bfa85f0c11d AS base
WORKDIR app
### __BEGIN_install
RUN cargo install --git https://github.com/NathanHowell/cargo-plan --branch master
### __END_install

FROM base AS planner
COPY --parents **/lib.rs **/main.rs **/Cargo.toml Cargo.lock ./
RUN cargo plan create -- --all-features --locked

FROM base AS builder
COPY --from=planner /app/cargo-plan.tar cargo-plan.tar
RUN cargo plan build -- --release --frozen
COPY . .
RUN cargo build --release --bins --frozen

FROM debian:trixie-slim@sha256:c85a2732e97694ea77237c61304b3bb410e0e961dd6ee945997a06c788c545bb
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
