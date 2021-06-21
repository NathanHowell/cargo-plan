FROM rust:1-slim-buster@sha256:f5c0990e84ba44d5d1f5aa5e93999f8cf982a8ef1f59e8a7ac815d81b999abd4 AS base
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

FROM debian:buster-slim@sha256:f077cd32bfea6c4fa8ddeea05c53b27e90c7fad097e2011c9f5f11a8668f8db4
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
