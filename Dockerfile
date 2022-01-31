FROM rust:1-slim-buster@sha256:39c58aeac4dd24844a837d252fed010034094953ced80c37b82061edd0606d8a AS base
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

FROM debian:buster-slim@sha256:abf70524e9b8a32c7453eeab4af6389468ca47bbe38b35e691651d6e6af6be55
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
