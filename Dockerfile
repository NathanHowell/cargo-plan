FROM rust:1-slim-buster@sha256:83cea37e899c5207318baf071ac2961daf6a079cbead18e0f2c68bf4efd72769 AS base
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

FROM debian:buster-slim@sha256:5dbce817ee72802025a38a388237b0ea576aa164bc90b7102b73aa42fef4d713
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
