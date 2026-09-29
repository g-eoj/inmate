#!/bin/bash
# Runs inside the VM before every command. inmate starts the VM with the project
# as the working directory; the per-project home lives inside it at
# <project>/.inmate/home. All state setup happens here rather than on the host
# so the host never writes through paths that code in the VM could have replaced.
set -euo pipefail

state_dir=$PWD/.inmate
export HOME="$state_dir/home"
mkdir -p "$HOME"

# Keep the state dir out of git and ripgrep without editing the project's own
# ignore files. A '*' pattern also matches the ignore file itself.
for f in .gitignore .ignore; do
  [ -e "$state_dir/$f" ] || printf '*\n' > "$state_dir/$f"
done

# With token auth, interactive Claude still shows onboarding and a login screen
# unless this is set (anthropics/claude-code#46259).
[ -e "$HOME/.claude.json" ] || printf '{"hasCompletedOnboarding": true}\n' > "$HOME/.claude.json"

# User-level installs and caches go under HOME so they outlive the VM. They go
# after the system PATH so nothing in the project can shadow the image's tools,
# in particular /usr/local/bin/claude.
export NPM_CONFIG_PREFIX="$HOME/.local"
export CARGO_HOME="$HOME/.cargo"
export PATH="$PATH:$NPM_CONFIG_PREFIX/bin:$CARGO_HOME/bin:$HOME/go/bin"

exec "$@"
