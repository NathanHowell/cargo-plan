FROM rust:1-slim-buster@sha256:f74250f6f5f7c506d6c59a503d1dd6dcb597299015f1bb6d84ecdc39cbb6e1cc AS base
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

FROM debian:buster-slim@sha256:b1af07039fe341833982bae85a2724ac8600ec5c74c37277c7a6ef7cddfb2cd0
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
