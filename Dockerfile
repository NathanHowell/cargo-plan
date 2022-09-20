FROM rust:1-slim-buster@sha256:94a84daf68b74214cf355f8ac46c2faabaa5a821714ddecb3298b29b05a9b590 AS base
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

FROM debian:buster-slim@sha256:7cd178f900adf3fe5659861895c9690750df784ca96839fa756c379af645747d
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
