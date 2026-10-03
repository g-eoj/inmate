# inmate

Run Claude Code in an Apple container VM that sees only your project directory.

```sh
cd ~/projects/some-app
inmate claude
```

`inmate` uses Apple's [`container`](https://github.com/apple/container), which runs each
container in its own lightweight VM. The VM gets exactly one host directory, the one you
ran `inmate` from. Your home directory, Keychain, SSH keys, and host Claude config
(`~/.claude`) are not visible inside it.

## Requirements

- Apple silicon Mac running macOS 26 or later
- `brew install container`
- A Claude Pro/Max/Team/Enterprise plan
- Optional: `gh` installed and logged in on the Mac, for GitHub access from the VM

## Install

```sh
git clone <this repo> ~/projects/inmate
ln -s ~/projects/inmate/bin/inmate ~/.local/bin/inmate
inmate setup
```

`inmate setup` starts the `container` service, builds the image, and logs you in to
Claude. The login is the only interactive step: it opens a browser URL and asks for the
code once. The resulting token is stored in the macOS Keychain and lasts a year. Run
`inmate setup` again to rebuild the image or log in again.

## Usage

```
inmate setup         build the image and log in to Claude (once)
inmate <cmd> [args]  run <cmd> in the VM
```

Everything after the command is passed through untouched:

```sh
inmate claude                 # Claude Code in the VM
inmate claude --continue      # Claude's own flags work as usual
inmate bash                   # a shell in the VM
inmate npm test
```

If no token is stored, `inmate` refuses to start and tells you to run `inmate setup`.
Claude never shows its own login screen inside the VM.

Claude keeps its normal permission prompts. If you pass `--dangerously-skip-permissions`,
it can run any command without asking, but only inside the VM.

## Cleaning up

Each `inmate` run creates a container that is removed when the command exits, so there is
normally nothing to clean up. If a terminal dies mid-session, the container can be left
behind. List and remove them with:

```sh
container ls -a                 # names start with inmate-
container rm -f <name>
```

`inmate setup` starts the `container` background service, which keeps running after you
exit. On its own it uses a few small processes and little memory; the VMs themselves exist
only while an `inmate` command runs. To shut the service down:

```sh
container system stop
```

The next `inmate` run starts it again.

## GitHub

If `gh` is logged in on the Mac, `inmate` passes its token into the VM as `GH_TOKEN`.
`gh` and `git push`/`fetch` over HTTPS work from inside the VM without further setup.
SSH remotes do not work: the VM has no SSH keys.

## MCP servers on the Mac

From inside the VM, the Mac is the network gateway. Find its address once:

```sh
container network ls        # shows the default subnet, e.g. 192.168.65.0/24
```

The gateway is the `.1` address of that subnet, `192.168.65.1` in this example. Point MCP
servers at it in the project's `.mcp.json`:

```json
{
  "mcpServers": {
    "example": { "type": "http", "url": "http://192.168.65.1:3000/mcp" }
  }
}
```

Only HTTP and SSE servers can be reached this way. A stdio server is a child process that
Claude would have to start on the Mac, which it can't do from the VM. Wrap it in a bridge
on the Mac instead. Example for Xcode's MCP server (Xcode 26.3+, with Xcode Tools enabled
under Settings → Intelligence and a project open):

```sh
# On the Mac, leave running:
npx -y supergateway --stdio "xcrun mcpbridge" --port 8765 --outputTransport streamableHttp
```

```json
{
  "mcpServers": {
    "xcode": { "type": "http", "url": "http://192.168.65.1:8765/mcp" }
  }
}
```

The bridge listens on all interfaces, so anything on your local network can reach it while
it runs.

## How it works

- **Same paths.** The project is mounted at the same absolute path inside the VM, so file
  paths match what you see on your Mac.
- **Fresh VM, persistent state.** Each run starts a new VM. `HOME` is
  `<project>/.inmate/home`, so Claude's config and history and tool caches persist per
  project. Git ignores `.inmate/` without changes to your own ignore files.
- **Root inside the VM.** `container` mounts have no UID mapping, so every file appears
  root-owned inside the VM. Files Claude creates are owned by you on the Mac.
- **Privacy settings are locked.** The image carries a Claude Code managed settings file
  that turns off telemetry, error reporting, feedback surveys, and auto-updates. Managed
  settings outrank every project and user setting.

## Known limitations

- **The tokens are readable inside the VM.** Anything running in the VM can read the
  Claude and GitHub tokens from the environment. Revoke them in your Claude and GitHub
  account settings if needed.
- **Claude can still damage the project**, including `.git`. Commit before long unattended
  sessions.
- **No Xcode.** The VM is Linux.
- **No image paste.** The VM can't see your clipboard.
- **Watch tools miss your edits.** Dev servers and test watchers in the VM notice Claude's
  edits but not yours (apple/container#141). Use their polling mode or run them on the Mac.
