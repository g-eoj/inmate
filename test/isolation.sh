#!/bin/bash
# Checks that a VM started by inmate can see the project directory and nothing
# else, and that the image carries its managed privacy settings. Uses the
# configured image; override it with INMATE_IMAGE. See test/host.sh for the
# directory-refusal checks, which need no VM.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
inmate="$root/bin/inmate"

# inmate only runs inside your home directory, so the test tree lives there.
base=$(mktemp -d "$HOME/.inmate-test.XXXXXX")
base=$(cd "$base" && pwd -P)
trap 'rm -rf "$base"' EXIT

export INMATE_ALLOW="$base/allowed"
project="$base/allowed/project"
outside="$base/outside"
mkdir -p "$project" "$outside"
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
check "managed privacy settings are in the image and parse" \
  in_vm "jq -e '.env.DISABLE_TELEMETRY == \"1\" and .feedbackSurveyRate == 0' \
    /etc/claude-code/managed-settings.d/10-inmate-privacy.json"

if [ "$failures" -gt 0 ]; then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nall checks passed\n'
