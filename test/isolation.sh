#!/bin/bash
set -uo pipefail

fails=0

check() {
  local desc=$1; shift
  if "$@" > /dev/null 2>&1; then printf 'ok   %s\n' "$desc"
  else printf 'FAIL %s\n' "$desc"; fails=$((fails + 1)); fi
}

project=$(mktemp -d ~/inmate-test.XXXX)
trap 'rm -rf "$project"' EXIT
cd "$project" || exit 1

out=$(script -q /dev/null inmate bash -c '
  echo
  echo "pwd=$PWD"
  echo "home=$HOME"
  echo "ssh=$(ls -d /Users/*/.ssh 2>/dev/null)"
  echo "token=${CLAUDE_CODE_OAUTH_TOKEN:+set}"
' | tr -d '\r')

check "project mounted at the same path" grep -qx "pwd=$project"               <<< "$out"
check "HOME is inside the project"       grep -qx "home=$project/.inmate/home" <<< "$out"
check "no .ssh visible"                  grep -qx "ssh="                       <<< "$out"
check "Claude token present"             grep -qx "token=set"                  <<< "$out"
check "refuses to run from home"         bash -c 'cd ~ && ! script -q /dev/null inmate true'

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
