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

# --- claude: native build, copied out of root's ~/.local so the per-project -----
# --- HOME can't shadow it.
WORKDIR /tmp
ARG CLAUDE_VERSION
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "$CLAUDE_VERSION" \
 && cp -L /root/.local/bin/claude /usr/local/bin/claude \
 && rm -rf /root/.local /root/.claude /root/.claude.json \
 && claude --version

# IS_SANDBOX=1 lets Claude run as root (the VM is the sandbox) if you opt into
# --dangerously-skip-permissions.
ENV IS_SANDBOX=1

# Claude policy lives in managed settings, which outrank every project and user
# setting: privacy (no telemetry, error reports, surveys, or feedback) and no
# auto-updates, since updates come from rebuilding the image. Each run starts a
# fresh VM, so a session can't make edits to /etc stick.
COPY managed-settings.d/ /etc/claude-code/managed-settings.d/
COPY entrypoint.sh /usr/local/bin/inmate-entrypoint
ENTRYPOINT ["/usr/local/bin/inmate-entrypoint"]
CMD ["bash"]
