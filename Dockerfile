FROM rust:1-slim-buster@sha256:8b04f5ac95c615b8939cad82448f5eeb7f2bb3cea6a8707de20ba2ac7d58434c AS base
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

FROM debian:buster-slim@sha256:acba41442b388703260ef3f782793ad1ae945028ab12ad6840e7d80d4abbec8d
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
