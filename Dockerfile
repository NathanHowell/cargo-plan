FROM rust:1-slim-buster@sha256:f56d3aebe63c98ee44d2e5d0e3690cd57ae771d747153eec777bdeadafb31c69 AS base
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

FROM debian:buster-slim@sha256:ca9003e9899b458d46b6ee6b040cf9e0d715acbc58e0615871f019c38ada8bc1
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
