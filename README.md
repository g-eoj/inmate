# inmate

[![CI](https://github.com/g-eoj/inmate/actions/workflows/lint.yml/badge.svg)](https://github.com/g-eoj/inmate/actions/workflows/lint.yml)

Run Claude Code in an Apple container VM that sees only your project directory.

```sh
cd ~/projects/some-app
inmate claude
```

`inmate` uses Apple's [`container`](https://github.com/apple/container), which runs each
container in its own lightweight VM. The VM gets exactly one host directory, the one you
ran `inmate` from. Your home directory, keychain, SSH keys, and host Claude config
(`~/.claude`) are not visible inside it. Network access is allowed.

## Requirements

- Apple silicon Mac running macOS 26 or later
- `brew install container`
- A Claude Pro/Max/Team/Enterprise plan, for `claude setup-token`

## Install

```sh
./install.sh      # symlinks bin/inmate into ~/.local/bin
inmate setup      # choose toolchains, store your tokens, build the image
```

`inmate setup` writes `~/.config/inmate/Dockerfile` from the toolchains you pick (Node,
Python, Go, Rust). Edit it to customize the image, then run `inmate build`.

Before the build, setup asks for your tokens and stores them in the macOS Keychain under
the service name `inmate`. You can skip either one and add it later with `inmate auth`.

- **Claude**, from `claude setup-token`. Claude Code doesn't need to be installed on your
  Mac: `inmate auth claude` runs `claude setup-token` in a throwaway VM that sees none of
  your files, then asks you to paste the token it printed. On a first setup there's no
  image to run it in yet, so setup offers this again after the build.
- **GitHub** (optional). inmate only stores it for now; it isn't passed into the VM yet.
  Every project's VM will share it, so create a
  [fine-grained token](https://github.com/settings/personal-access-tokens/new) that covers
  only the repos you use with inmate, without the Workflows permission. Don't reuse
  `gh auth token` from your Mac: it covers all your repos and can change workflows.

Don't log in inside the VM instead (Claude's `/login`, `gh auth login`). See Known
limitations.

Set `INMATE_TOOLCHAINS` (`all`, or a comma list of fragment labels like `node,python`) to
skip the toolchain prompts, e.g. for a scripted install or CI.

## Usage

| Command | What it does |
|---|---|
| `inmate claude [args]` | Claude Code in the VM. Args pass through, e.g. `--continue` |
| `inmate <cmd> [args]` | Any other command, e.g. `inmate bash` or `inmate npm test` |
| `inmate build` | Rebuild the image after editing the Dockerfile |
| `inmate update` | Update Claude Code in the image |
| `inmate dockerfile <path>` | Write the assembled Dockerfile to `<path>` without building |
| `inmate auth` | List which tokens are stored (names only, never values) |
| `inmate auth claude` | Get a new Claude token and store it. `inmate token` does the same |
| `inmate auth github` | Store a GitHub token |

Claude keeps its normal permission prompts. If you pass `--dangerously-skip-permissions`,
it can run any command without asking, but only inside the VM.

## How it works

- **Same paths.** The project is mounted at the same absolute path inside the VM, so file
  paths match what you see on your Mac.
- **Fresh VM, persistent state.** Each run starts a new VM. `HOME` is
  `<project>/.inmate/home`, so Claude's config and history, plus tool caches (npm, pip, uv,
  cargo, Go modules), persist per project. Git ignores `.inmate/` without changes to your
  own ignore files.
- **Root inside the VM.** `container` mounts have no UID mapping, so every file appears
  root-owned inside the VM. Files Claude creates are owned by you on the Mac.
- **Symlinks can't escape.** A symlink in the project that points at `~/.ssh` resolves
  inside the VM, where that path doesn't exist.
- **Privacy settings are locked.** The image carries a Claude Code managed settings file,
  `image/managed-settings.d/10-inmate-privacy.json`, that turns off telemetry, error
  reporting, feedback surveys, the `/feedback` command, and auto-updates. Managed settings
  outrank every project and user setting, and each run starts from the image, so nothing
  in the project can turn them back on. Run `/status` in Claude to see
  `Enterprise managed settings (drop-ins)`.

Two things no local setting controls:

- **Model training** on your conversations is an account setting: claude.ai → Settings →
  Data privacy controls.
- **Transcripts** are stored in the project, under `.inmate/home/.claude/projects/`. Git
  ignores them, but anything that can read the project can read them.

## Configuration

`~/.config/inmate/config`, one `key=value` per line:

```
image=inmate:latest
memory=8g
cpus=4
allow=~/projects
```

inmate only runs in directories below your home directory. Optional `allow=` lines narrow
this: if any are present, the project must be one of them or inside one. Give each as an
absolute path or `~/...`. inmate also refuses any project that contains its own files
(`~/.config/inmate`, the inmate checkout, `~/.local/bin`, and the directory of the `inmate`
link you ran), so the VM can't change them.

`INMATE_IMAGE`, `INMATE_MEMORY`, `INMATE_CPUS`, and `INMATE_ALLOW` (entries separated by
`:`) override the file.

## Known limitations

- **The Claude token is readable inside the VM.** Anything running in the VM can read it from the
  environment. It only permits model requests, and you can revoke it in your Claude
  account settings.
- **Logging in inside the VM stores a plaintext credential in the project.** The VM has
  no keychain, so Claude's `/login` writes `.inmate/home/.claude/.credentials.json`, and
  `gh auth login` writes `.inmate/home/.config/gh/hosts.yml`. That's a full login, and
  anything in the VM or with access to the project can read it. inmate warns about these
  files every time it starts, but doesn't delete them. Delete them yourself, then run
  `inmate auth claude` or `inmate auth github`.
- **The GitHub token isn't used yet.** The image has no `gh`, and inmate doesn't pass the
  token into the VM.
- **Claude can still damage the project**, including `.git`. Commit or push before long
  unattended sessions.
- **No Xcode.** The VM is Linux.
- **No image paste.** The VM can't see your clipboard.
- **Watch tools miss your edits.** Dev servers and test watchers in the VM notice Claude's
  edits but not yours, because the Mac doesn't pass file-change events into the VM
  (apple/container#141). Use their polling mode or run them on the Mac. Claude itself
  still sees your edits.
- **Terminal workaround.** `inmate` turns off `onlcr` on your terminal while the VM runs,
  to work around apple/container#2299, and restores it on exit.

## Tests

```sh
test/isolation.sh     # checks the VM sees the project and nothing else
test/host.sh          # checks inmate refuses directories it shouldn't, no VM needed
```
