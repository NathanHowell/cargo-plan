FROM rust:1-slim-buster@sha256:07cdd2f133663d267034f78ca75c62490199ff20e2b4a9cd5284ccba3a2cd7b4 AS base
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
