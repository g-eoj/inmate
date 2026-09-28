# --- python: Debian's python3 + uv -> /usr/local/bin ----------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-dev python3-pip python3-venv \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh \
 && uv --version
