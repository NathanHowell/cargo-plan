FROM rust:1-slim@sha256:b0b99a29bfa1a80a95051b7608ac44a0e4cbe20bdba466e43fd52492fb334eaf AS base
WORKDIR app
RUN cargo install --git https://github.com/NathanHowell/cargo-plan --branch master

FROM base AS planner
COPY . .
RUN cargo plan generate -- --all-features

FROM base AS builder
COPY --from=planner /app/cargo-plan.tar cargo-plan.tar
RUN cargo plan build -- --release
COPY . .
RUN cargo build --release --bins

FROM gcr.io/distroless/base@sha256:54ec1c780633580e1a0cf3c4a645643971cfc6e418b1d3e4c4df06b7fbc95f88
COPY --from=builder /app/target/release release