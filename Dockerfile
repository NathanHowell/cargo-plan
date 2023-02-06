FROM rust:1-slim-buster@sha256:6e24a7d04fcdfbc515533be6b9a21b3d75a6dc9674a2f335b43a9bf5e986b9de AS base
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

FROM debian:buster-slim@sha256:25ab4ba4a3fe99e4e1329292b3d93a6c51b5cf4f0525d8408713fc3522d120f5
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
