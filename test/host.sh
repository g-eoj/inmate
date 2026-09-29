#!/bin/bash
# Checks that inmate refuses directories it shouldn't expose. check_project_dir
# runs before inmate ever calls `container`, so these checks need no VM and
# can run on a hosted runner without Apple `container` installed. See
# test/isolation.sh for the checks that do need a VM.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
inmate="$root/bin/inmate"

# inmate only runs inside your home directory, so the test tree lives there.
base=$(mktemp -d "$HOME/.inmate-host-test.XXXXXX")
base=$(cd "$base" && pwd -P)
outside_home=$(mktemp -d "${TMPDIR:-/tmp}/inmate-host-test.XXXXXX")
trap 'rm -rf "$base" "$outside_home"' EXIT

# Only $base/allowed is on the allowlist. The other dirs must be refused,
# including allowed-old, whose path starts with the same characters.
export INMATE_ALLOW="$base/allowed"
outside="$base/outside"
lookalike="$base/allowed-old/project"
mkdir -p "$base/allowed/project" "$outside" "$lookalike"

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

# Pass only if inmate refuses the directory. The bogus image means that if
# inmate fails to refuse, it stops at the image check without mounting anything.
refuses() {
  local out
  out=$(cd "$1" && INMATE_IMAGE=inmate-test/no-such-image "$inmate" true 2>&1) || true
  grep -q 'refusing to expose' <<< "$out"
}

check "refuses to run in /" refuses /
check "refuses to run in \$HOME" refuses "$HOME"
check "refuses a directory outside \$HOME" refuses "$outside_home"
check "refuses a directory outside allow=" refuses "$outside"
check "refuses a look-alike of an allowed directory" refuses "$lookalike"
INMATE_ALLOW=":$base/allowed" check "an empty allow= entry doesn't allow everything" refuses "$outside"
INMATE_ALLOW=. check "a relative allow= entry doesn't allow everything" refuses "$outside"
INMATE_ALLOW=$root check "refuses the directory holding inmate itself" refuses "$root/bin"

if [ "$failures" -gt 0 ]; then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nall checks passed\n'
