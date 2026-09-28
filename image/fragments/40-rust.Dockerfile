# --- rust: rustup toolchains in /usr/local; the entrypoint points CARGO_HOME ----
# --- at the project home so the registry cache and `cargo install` persist -----
ENV RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs \
      | CARGO_HOME=/usr/local/cargo sh -s -- -y --no-modify-path --profile minimal --component rustfmt,clippy \
 && rustc --version
