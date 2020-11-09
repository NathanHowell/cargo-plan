FROM rust:1-slim@sha256:2a902de987345f126fe59daca200afae1fccb6f68e14e9a27c0fd9cf39f9743f AS base
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