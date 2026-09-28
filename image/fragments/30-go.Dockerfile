# --- go: latest stable release -> /usr/local/go ---------------------------------
RUN set -eux; \
    version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"; \
    curl -fsSL "https://go.dev/dl/${version}.linux-$(dpkg --print-architecture).tar.gz" \
      | tar -xz -C /usr/local; \
    /usr/local/go/bin/go version
ENV PATH=/usr/local/go/bin:$PATH
