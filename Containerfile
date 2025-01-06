FROM docker.io/rust:alpine AS builder

ARG TRIPSU_VERSION="0.2.0"

WORKDIR /app/
RUN USER=root

RUN apk add --no-cache \
  git \
  musl-dev \
  pkgconfig

# compile tripsu for musl
RUN git clone https://github.com/sdsc-ordes/tripsu.git /app/tripsu && \
  cd /app/tripsu && \
  git checkout tags/v${TRIPSU_VERSION} && \
  cargo build  --release

FROM alpine:3.20

RUN apk add --no-cache \
  bash \
  coreutils \
  curl \
  envsubst \
  findutils \
  jq \
  just \
  watchexec

# Include required binaries into the image
COPY --from=builder /app/tripsu/target/release/tripsu /usr/bin/tripsu
WORKDIR /app

ENTRYPOINT ["/bin/bash"]
