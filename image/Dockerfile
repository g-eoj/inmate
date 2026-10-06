# base: Debian + the CLI tools Claude Code expects
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl file gh git jq less \
    procps ripgrep tzdata unzip xz-utils \
  && rm -rf /var/lib/apt/lists/*

# claude: native build, copied out of root's ~/.local
# so the per-project HOME can't shadow it.
WORKDIR /tmp
ARG CLAUDE_VERSION
RUN curl -fsSL https://claude.ai/install.sh | bash -s -- "$CLAUDE_VERSION" \
  && cp -L /root/.local/bin/claude /usr/local/bin/claude \
  && rm -rf /root/.local /root/.claude /root/.claude.json \
  && claude --version
# Claude policy lives in managed settings, which outrank every project and user setting
COPY managed-settings.d/ /etc/claude-code/managed-settings.d/
# Claude user defaults seed new projects exactly one time,
# delete .inmate/home/.claude/settings.json to reseed.
COPY defaults.d/ /usr/local/share/inmate/defaults.d/
# Merge user defaults; a malformed JSON fails the build
RUN jq -s 'reduce .[] as $s ({}; . * $s)' /usr/local/share/inmate/defaults.d/*.json \
  > /usr/local/share/inmate/settings.json
COPY statusline.sh /usr/local/bin/inmate-statusline

# uv: for Python
# Default cache settings double .inmate disk storage usage.
# So keep cache on ephemeral disk. venv is still kept in .inmate.
ENV UV_CACHE_DIR=/var/cache/uv \
  UV_LINK_MODE=copy
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

COPY entrypoint.sh /usr/local/bin/inmate-entrypoint
ENTRYPOINT ["/usr/local/bin/inmate-entrypoint"]
