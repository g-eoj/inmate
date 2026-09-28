# inmate

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
inmate setup      # choose toolchains, build the image, store your token
```

`inmate setup` writes `~/.config/inmate/Dockerfile` from the toolchains you pick (Node,
Python, Go, Rust). Edit it to customize the image, then run `inmate build`. The token is
stored in the macOS Keychain under the service name `inmate`.

## Usage

| Command | What it does |
|---|---|
| `inmate claude [args]` | Claude Code in the VM. Args pass through, e.g. `--continue` |
| `inmate <cmd> [args]` | Any other command, e.g. `inmate bash` or `inmate npm test` |
| `inmate build` | Rebuild the image after editing the Dockerfile |
| `inmate update` | Update Claude Code in the image |
| `inmate token` | Replace the stored token |

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
(`~/.config/inmate`, the inmate checkout, `~/.local/bin`), so the VM can't change them.

`INMATE_IMAGE`, `INMATE_MEMORY`, `INMATE_CPUS`, and `INMATE_ALLOW` (entries separated by
`:`) override the file.

## Known limitations

- **The token is readable inside the VM.** Anything running in the VM can read it from the
  environment. It only permits model requests, and you can revoke it in your Claude
  account settings.
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
```
