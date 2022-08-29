FROM rust:1-slim-buster@sha256:6a43f45433cd13be7dc88289a01072dd7973641e92bed5417fcfe3f4deefcd74 AS base
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
