FROM rust:1-slim-buster@sha256:6ad6ba4009db173c701fa64b515485eae6cf950e917363664a95fea62414fa59 AS base
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
