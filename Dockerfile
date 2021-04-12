FROM rust:1-slim-buster@sha256:eb35fd0f970f3a32d21f5b39b6320cdc0baf0c0603cd15df16d4d364c78faf19 AS base
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

FROM debian:buster-slim@sha256:b586cf8c850cada85a47599f08eb34ede4a7c473551fd7c68cbf20ce5f8dbbf1
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
