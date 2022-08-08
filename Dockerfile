FROM rust:1-slim-buster@sha256:75d6ed2fd51b3e3f4d2e1b34fc41e71f86a0a51f074832b898cdf24af05fe188 AS base
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

FROM debian:buster-slim@sha256:5b0b1a9a54651bbe9d4d3ee96bbda2b2a1da3d2fa198ddebbced46dfdca7f216
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
