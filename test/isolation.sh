#!/bin/bash
# Checks that a VM started by inmate can see the project directory and nothing
# else, that the image carries its managed privacy settings, and that tokens
# stay out of sight. Uses the configured image; override it with INMATE_IMAGE.
# See test/host.sh for the directory-refusal checks, which need no VM.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
inmate="$root/bin/inmate"

# Keychain entries go under a test-only service, so the tests never read or
# change your real tokens.
export INMATE_KEYCHAIN_SERVICE="inmate-test-$$"
fake_token="inmate-test-token-$$-$RANDOM"

# inmate only runs inside your home directory, so the test tree lives there.
base=$(mktemp -d "$HOME/.inmate-test.XXXXXX")
base=$(cd "$base" && pwd -P)
cleanup() {
  rm -rf "$base"
  security delete-generic-password -s "$INMATE_KEYCHAIN_SERVICE" -a claude-code-oauth-token > /dev/null 2>&1 || true
}
trap cleanup EXIT

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

# Plant a login file ($1, relative to the VM's HOME) in the project. Starting a
# VM must print its path and the fix, `inmate auth $2`, and keep the file.
warns_about_login() {
  local file="$project/.inmate/home/$1" out
  mkdir -p "$(dirname "$file")"
  printf '{}\n' > "$file"
  out=$(cd "$project" && "$inmate" true 2>&1) || return 1
  grep -qF "$file" <<< "$out" && grep -qF "inmate auth $2" <<< "$out" && [ -e "$file" ]
}

# While a VM runs, the token must be in its environment but in no host
# process's arguments. The VM reports the token in a file once it's up, then
# waits (up to a minute) for the host to finish looking at `ps`.
token_not_in_ps() {
  local seen="$project/.inmate/token-seen" done="$project/.inmate/ps-done" pid procs
  rm -f "$seen" "$done"
  # shellcheck disable=SC2016 # expanded by the shell in the VM
  (cd "$project" && CLAUDE_CODE_OAUTH_TOKEN=$fake_token "$inmate" sh -c '
    printenv CLAUDE_CODE_OAUTH_TOKEN > .inmate/token-seen
    i=0
    while [ ! -e .inmate/ps-done ] && [ $i -lt 600 ]; do sleep 0.1; i=$((i + 1)); done
  ') > /dev/null 2>&1 &
  pid=$!
  for _ in $(seq 600); do
    [ -s "$seen" ] && break
    sleep 0.1
  done
  procs=$(ps -axww -o command=)
  touch "$done"
  wait "$pid" || return 1
  # Compare in bash, not with grep, whose own arguments would hold the token.
  [ "$(cat "$seen")" = "$fake_token" ] && [[ $procs != *"$fake_token"* ]]
}

# `inmate auth` names the stored tokens without printing them. The fake token
# uses the account older versions stored the Claude token under.
auth_lists_names() {
  local out
  security add-generic-password -s "$INMATE_KEYCHAIN_SERVICE" \
    -a claude-code-oauth-token -w "$fake_token" || return 1
  out=$("$inmate" auth) || return 1
  grep -q '^claude  *stored$' <<< "$out" && grep -q '^github  *not stored$' <<< "$out" &&
    [[ $out != *"$fake_token"* ]]
}

check "your home shows only the path to the project" \
  in_vm "[ \"\$(ls -A '$HOME')\" = '$(basename "$base")' ]"
check "siblings of the project are not visible" \
  in_vm "[ \"\$(ls -A '$(dirname "$project")')\" = '$(basename "$project")' ]"
check "a symlink to a file outside the project dangles" in_vm "[ ! -e link-to-secret ]"
check "the VM can write to the project" in_vm "echo hi > from-vm.txt"
check "files written in the VM are owned by you" test -O "$project/from-vm.txt"
check ".inmate/ exists and is ignored by git" ignored_by_git
check "a Claude login in the VM is warned about and kept" \
  warns_about_login .claude/.credentials.json claude
check "a gh login in the VM is warned about and kept" \
  warns_about_login .config/gh/hosts.yml github
check "the token reaches the VM but not host ps output" token_not_in_ps
check "inmate auth lists token names, not values" auth_lists_names
check "managed privacy settings are in the image and parse" \
  in_vm "jq -e '.env.DISABLE_TELEMETRY == \"1\" and .feedbackSurveyRate == 0' \
    /etc/claude-code/managed-settings.d/10-inmate-privacy.json"

if [ "$failures" -gt 0 ]; then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nall checks passed\n'
