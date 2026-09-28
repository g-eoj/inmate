#!/bin/bash
# Puts `inmate` on your PATH by symlinking it into ~/.local/bin.
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd -P)
bin_dir="$HOME/.local/bin"

mkdir -p "$bin_dir"
ln -sfn "$root/bin/inmate" "$bin_dir/inmate"
printf 'Linked %s -> %s\n' "$bin_dir/inmate" "$root/bin/inmate"

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'Note: %s is not on your PATH yet.\n' "$bin_dir" ;;
esac
printf 'Next: inmate setup\n'
