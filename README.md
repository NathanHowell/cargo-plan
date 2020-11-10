# Docker Friendly Build Plans for Cargo

Cargo has long been missing a [build --dependencies-only](https://github.com/rust-lang/cargo/issues/2644)
feature, prompting various hacks and workarounds especially for Docker builds.

This package aims to use existing tools and file formats whenever possible:
* `cargo metadata` is used to generate a minimal buildable project mirroring the current one
* The output is a standard Tar archive containing stubs in place of source files, trivial to copy and inspect
* Post-build cleaning of compiled stubs is completed with `cargo clean`
* `Dockerfile` generation uses a template that is updated by Dependabot

## Usage

To inspect this locally run this script:
```shell script
#!/usr/bin/env bash
cd /path/to/project
cargo plan create
mkdir /tmp/example
cp cargo-plan.tar /tmp/example/
pushd /tmp/example
cargo plan build
```

## Example Dockerfile

Running `cargo plan generate-dockefile` produces a `Dockerfile` specialized for the current project.
If there are multiple binary targets it picks an arbitrary target as it's entrypoint.

```dockerfile
FROM rust:1-slim-buster@sha256:b0b99a29bfa1a80a95051b7608ac44a0e4cbe20bdba466e43fd52492fb334eaf AS base
WORKDIR app
RUN cargo install --git https://github.com/NathanHowell/cargo-plan --rev e3f594ae62b2b4c6861458e41bb7079345b3efa7

FROM base AS planner
COPY . .
RUN cargo plan create -- --all-features --locked

FROM base AS builder
COPY --from=planner /app/cargo-plan.tar cargo-plan.tar
RUN cargo plan build -- --release --frozen
COPY . .
RUN cargo build --release --bins --frozen

FROM debian:buster-slim@sha256:1be41347adaee8303bf12114b9edf4af0b35a5e1d9756b3ddad59856eaa31ea7
WORKDIR app
COPY --from=builder ["/app/target/release/cargo-plan", "./"]
ENTRYPOINT ["/app/cargo-plan"]
```