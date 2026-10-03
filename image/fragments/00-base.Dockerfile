# --- base: Debian + the CLI tools Claude Code expects -------------------------
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl file gh git jq less openssh-client \
      procps ripgrep tzdata unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
