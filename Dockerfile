FROM rust:1-slim-buster@sha256:a3f87a1159a23df13ec23fe90119cbc8d40f3baaae1e6f3eecde8b0518d9b167 AS base
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

FROM debian:buster-slim@sha256:cd0a14fb400adf6bcb8c97d25062b71d82d3299a9861aae13ac006708dbc68a5
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
