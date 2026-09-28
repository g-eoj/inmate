#!/bin/bash
# Checks that a VM started by inmate can see the project directory and nothing
# else, and that inmate refuses directories it shouldn't expose. Uses the
# configured image; override it with INMATE_IMAGE.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
inmate="$root/bin/inmate"

# inmate only runs inside your home directory, so the test tree lives there.
base=$(mktemp -d "$HOME/.inmate-test.XXXXXX")
base=$(cd "$base" && pwd -P)
outside_home=$(mktemp -d "${TMPDIR:-/tmp}/inmate-test.XXXXXX")
trap 'rm -rf "$base" "$outside_home"' EXIT

# Only $base/allowed is on the allowlist. The other dirs must be refused,
# including allowed-old, whose path starts with the same characters.
export INMATE_ALLOW="$base/allowed"
project="$base/allowed/project"
outside="$base/outside"
lookalike="$base/allowed-old/project"
mkdir -p "$project" "$outside" "$lookalike"
echo secret > "$outside/secret.txt"
ln -s "$outside/secret.txt" "$project/link-to-secret"
git -C "$project" init -q

failures=0
check() {
  local desc=$1
  shift
  if "$@"; then
    printf 'ok    %s\n' "$desc"
  else
    printf 'FAIL  %s\n' "$desc"
    failures=$((failures + 1))
  fi
}

# Run a shell snippet in a VM whose project is $project.
in_vm() { (cd "$project" && "$inmate" sh -c "$1") > /dev/null 2>&1; }

# Pass only if inmate refuses the directory. The bogus image means that if
# inmate fails to refuse, it stops at the image check without mounting anything.
refuses() {
  local out
  out=$(cd "$1" && INMATE_IMAGE=inmate-test/no-such-image "$inmate" true 2>&1) || true
  grep -q 'refusing to expose' <<< "$out"
}

# Run a command with INMATE_ALLOW set to $1.
with_allow() { local a=$1; shift; INMATE_ALLOW=$a "$@"; }

ignored_by_git() {
  [ -d "$project/.inmate" ] && [ -z "$(git -C "$project" status --porcelain -- .inmate)" ]
}

check "your home shows only the path to the project" \
  in_vm "[ \"\$(ls -A '$HOME')\" = '$(basename "$base")' ]"
check "siblings of the project are not visible" \
  in_vm "[ \"\$(ls -A '$(dirname "$project")')\" = '$(basename "$project")' ]"
check "a symlink to a file outside the project dangles" in_vm "[ ! -e link-to-secret ]"
check "the VM can write to the project" in_vm "echo hi > from-vm.txt"
check "files written in the VM are owned by you" test -O "$project/from-vm.txt"
check ".inmate/ exists and is ignored by git" ignored_by_git
check "refuses to run in /" refuses /
check "refuses to run in \$HOME" refuses "$HOME"
check "refuses a directory outside \$HOME" refuses "$outside_home"
check "refuses a directory outside allow=" refuses "$outside"
check "refuses a look-alike of an allowed directory" refuses "$lookalike"
check "an empty allow= entry doesn't allow everything" with_allow ":$base/allowed" refuses "$outside"
check "a relative allow= entry doesn't allow everything" with_allow "." refuses "$outside"
check "refuses the directory holding inmate itself" \
  with_allow "$root" refuses "$root/bin"

if [ "$failures" -gt 0 ]; then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nall checks passed\n'
