# --- base: Debian + the CLI tools Claude Code expects -------------------------
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Later fragments pipe curl into tar/sh; without pipefail a failed download
# wouldn't fail the build (hadolint DL4006).
SHELL ["/bin/bash", "-c", "-o", "pipefail"]

# Track Debian trixie's current versions, not a pin that would just go stale.
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl file git jq less openssh-client \
      procps ripgrep tzdata unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
