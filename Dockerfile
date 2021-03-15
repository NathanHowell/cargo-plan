FROM rust:1-slim-buster@sha256:5dd85eb0c60bbdea14a6ecba1f6fe4a0f5c878bcf06d2cdfae0aff3a19ed4b10 AS base
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

FROM debian:buster-slim@sha256:8bf6c883f182cfed6375bd21dbf3686d4276a2f4c11edc28f53bd3f6be657c94
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
