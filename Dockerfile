FROM rust:1-slim-buster@sha256:86e0c282782837bf71d78a72aa3dcf9e54596ca5bf5539cf86ab055c173fa400 AS base
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

FROM debian:buster-slim@sha256:69f5980eb8901ca6829d36f2aea008f3cdb39a23aec23511054a6801244cbaa5
WORKDIR app
### __BEGIN_copy
COPY --from=builder /app/target/release ./
### __END_copy
