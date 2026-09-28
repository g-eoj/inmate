# --- claude: native build, copied out of root's ~/.local so the per-project -----
# --- HOME can't shadow it. `inmate update` changes the ARG to refresh this layer.
WORKDIR /tmp
ARG CLAUDE_CACHE_BUST=0
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && cp -L /root/.local/bin/claude /usr/local/bin/claude \
 && rm -rf /root/.local /root/.claude /root/.claude.json \
 && claude --version

# Updates come from rebuilding the image. IS_SANDBOX=1 lets Claude run as root
# (the VM is the sandbox) if you opt into --dangerously-skip-permissions.
ENV DISABLE_AUTOUPDATER=1 \
    IS_SANDBOX=1

COPY entrypoint.sh /usr/local/bin/inmate-entrypoint
ENTRYPOINT ["/usr/local/bin/inmate-entrypoint"]
CMD ["bash"]
