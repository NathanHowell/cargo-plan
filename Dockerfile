FROM rust:1-slim-buster@sha256:c705fdbdfd8292a63b8da7c85a23d645ad25f4f18398b95382e1e57cd07be5e2 AS base
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

FROM debian:buster-slim@sha256:91b2ec3340d52126267e0ff5dbb3cfd4c97c3a20b161a6f5ce7ca9560ec1794f
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
