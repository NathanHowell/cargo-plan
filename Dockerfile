FROM rust:1-slim-buster@sha256:6eeacb92fcaeb28294cf9de2b195fdc63b88dc53d792c19a9b39fbf53df7a1b7 AS base
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

FROM debian:buster-slim@sha256:331c322cc893f17b74245542f6c2f3dd8a66cc066ae66c2d5d3c96bb4bf328cb
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
