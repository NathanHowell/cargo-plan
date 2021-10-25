FROM rust:1-slim-buster@sha256:ffca685ec87996832ea0818177e3c01fada37149b480bb7574a27656ed818310 AS base
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

FROM debian:buster-slim@sha256:544c93597c784cf68dbe492ef35c00de7f4f6a990955c7144a40b20d86a3475f
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
