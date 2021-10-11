FROM rust:1-slim-buster@sha256:d5846fde30cbe74acf55cd5c64099a1a78aafec213a0c6288af31cb205d5d5ae AS base
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

FROM debian:buster-slim@sha256:a364ab17ed74911bf0913ce1099054e9bcbabc80bf0faae7dac4d3470b472e24
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
