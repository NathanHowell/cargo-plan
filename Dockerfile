FROM rust:1-slim-buster@sha256:563dca35910749060f93addfb92f527f5c5f4cc57af9f9098bb1713b5520cd3b AS base
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

FROM debian:buster-slim@sha256:fda76aa2ef4867e583dc8a7b86bbdb51118b8794c1b98aa4aeebaca3a1ad9c0f
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
