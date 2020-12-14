FROM rust:1-slim-buster@sha256:4fdb69c30a4545f7ee40edd4d3af330bacababe236ce38bab7f7ca3a3dce7925 AS base
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

FROM debian:buster-slim@sha256:bb5473161a03d24b397c46778e58f845e29f1ce42a2953666ef8289f00afda42
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
