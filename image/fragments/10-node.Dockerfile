# --- node: latest LTS release -> /usr/local ------------------------------------
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in amd64) arch=x64 ;; esac; \
    version="$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts)][0].version')"; \
    curl -fsSL "https://nodejs.org/dist/${version}/node-${version}-linux-${arch}.tar.xz" \
      | tar -xJ -C /usr/local --strip-components=1 --no-same-owner; \
    node --version; npm --version
