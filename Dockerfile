FROM rust:1-slim-buster@sha256:bd4d19faf29b95d32ab67375c2edb3abb589c19e3b6beaedfa481b3f385d2dfe AS base
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

FROM debian:buster-slim@sha256:bbf8ca5a94fe10b78b681d0f4efe8dbc23839d26e811ab6a1f252c7663c7e244
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
