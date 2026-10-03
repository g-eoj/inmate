# --- claude: native build, copied out of root's ~/.local so the per-project -----
# --- HOME can't shadow it. `inmate setup` always changes CLAUDE_CACHE_BUST so latest Claude Code is used.
WORKDIR /tmp
ARG CLAUDE_CACHE_BUST=0
RUN curl -fsSL https://claude.ai/install.sh | bash \
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
