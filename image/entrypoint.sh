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

# Seed default user settings once
mkdir -p "$HOME/.claude"
settings="$HOME/.claude/settings.json"
[ -e "$settings" ] || cp /usr/local/share/inmate/settings.json "$settings"

# Prepare for Xcode
xcode_entry='{"type":"stdio","command":"inmate-xcode-mcp","args":[],"env":{}}'

register_xcode() {
  local f=$HOME/.claude.json
  # already registered
  jq -e --argjson s "$xcode_entry" '.mcpServers.Xcode == $s' "$f" > /dev/null && return
  # an Xcode server entry already exists
  if jq -e '.mcpServers.Xcode | . != null and .command != "inmate-xcode-mcp"' "$f" > /dev/null; then
    printf "inmate: existing Xcode MCP server detected; Xcode bridge not registered\n" >&2
    return
  fi
  jq --argjson s "$xcode_entry" '.mcpServers.Xcode = $s' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# Xcode config prepared but disabled by default
if [ -n "${INMATE_XCODE_BRIDGE_ADDR-}" ]; then
  rm -f /etc/claude-code/managed-settings.d/50-inmate-xcode-off.json
  register_xcode || printf 'inmate: could not register the Xcode MCP server\n' >&2
fi

# Use HTTPS credentials for GitHub
[ -n "${GH_TOKEN-}" ] && gh auth setup-git

exec "$@"
