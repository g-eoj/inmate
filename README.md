# inmate

Run Claude Code in an Apple container VM that sees only your project directory.

```sh
cd ~/projects/some-app
inmate claude
```

`inmate` uses Apple's [`container`](https://github.com/apple/container), which runs each
container in its own lightweight VM. The VM is given one host directory: the one you ran
`inmate` from. It cannot see your home directory, Keychain, SSH keys, or host Claude
config. It does have normal network access; see [Known limitations](#known-limitations).

## Requirements

- Apple silicon Mac running macOS 26 or later
- `brew install container`
- A Claude Pro, Max, Team, or Enterprise plan
- Optional: a GitHub fine-grained personal access token, for GitHub access from the VM

## Install

```sh
git clone <this repo> ~/projects/inmate
ln -s ~/projects/inmate/bin/inmate ~/.local/bin/inmate
inmate setup
```

`inmate setup` does four things:

1. Starts the `container` service.
2. Builds the image with the current Claude Code release.
3. Logs you in to Claude. This opens a browser URL and asks for a code once. The token
   is stored in the macOS Keychain and lasts a year.
4. Asks for a GitHub token, also stored in the Keychain. Press Enter to skip.

Run `inmate setup` again to update Claude Code or to log in again.

## Usage

```
inmate setup         build the image and log in (once)
inmate <cmd> [args]  run <cmd> in the VM
```

Everything after `inmate` is passed through untouched:

```sh
inmate claude                 # Claude Code in the VM
inmate claude --continue      # Claude's own flags work as usual
inmate bash                   # a shell in the VM
```

- If no Claude token is stored, `inmate` refuses to start and tells you to run
  `inmate setup`. Claude never shows its own login screen inside the VM.
- Claude keeps its normal permission prompts. With `--dangerously-skip-permissions` it
  runs any command without asking, but only inside the VM.

## GitHub

Inside the VM, `gh` and `git push`/`fetch` over HTTPS use the token from `inmate setup`.
SSH remotes do not work: the VM has no SSH keys.

Anything running in the VM can read the token, so scope it to the repos you work on:

1. On GitHub, open Settings → Developer settings → Personal access tokens → Fine-grained
   tokens.
2. Under Repository access, choose "Only select repositories" and pick your repos.
3. Under Permissions, grant Contents: Read and write. Add Pull requests and Issues if
   you want `gh pr` and `gh issue`.
4. Run `inmate setup` and paste the token when asked.

Run `inmate setup` again to replace the token.

## MCP servers on the Mac

From inside the VM, the Mac is the network gateway, so HTTP and SSE MCP servers running
on the Mac are reachable.

1. Find the gateway address once. It is the `.1` address of the default subnet:

   ```sh
   container network ls        # e.g. 192.168.65.0/24, so the gateway is 192.168.65.1
   ```

2. Point the server at it in the project's `.mcp.json`:

   ```json
   {
     "mcpServers": {
       "example": { "type": "http", "url": "http://192.168.65.1:3000/mcp" }
     }
   }
   ```

A stdio server is a child process that Claude would have to start on the Mac, which it
can't do from the VM. Wrap it in an HTTP bridge on the Mac instead. Example for Xcode's
MCP server, which needs Xcode 26.3+, Xcode Tools enabled under Settings → Intelligence,
and a project open:

1. On the Mac, start the bridge and leave it running:

   ```sh
   npx -y supergateway --stdio "xcrun mcpbridge" --port 8765 --outputTransport streamableHttp
   ```

2. Add it to the project's `.mcp.json`:

   ```json
   {
     "mcpServers": {
       "xcode": { "type": "http", "url": "http://192.168.65.1:8765/mcp" }
     }
   }
   ```

The bridge listens on all interfaces with no authentication. While it runs, the VM and
anything else on your local network can drive Xcode on your Mac through it. That is a
deliberate hole in the isolation. Stop the bridge when you are done.

## Cleaning up

Each run creates a container that is removed when the command exits. If a terminal dies
mid-session, the container can be left behind:

```sh
container ls -a                 # names start with inmate-
container rm -f <name>
```

`inmate setup` starts the `container` background service, which keeps running after you
exit. It is small on its own; the VMs exist only while an `inmate` command runs. To stop
it:

```sh
container system stop
```

The next `inmate` run starts it again.

## How it works

- **Same paths.** The project is mounted at the same absolute path inside the VM, so
  file paths match what you see on your Mac.
- **Fresh VM, persistent state.** Each run starts a new VM. `HOME` is
  `<project>/.inmate/home`, so Claude's config, history, and tool caches persist per
  project. Git ignores `.inmate/` without changes to your own ignore files.
- **Root inside the VM.** `container` mounts have no UID mapping, so every file appears
  root-owned inside the VM. Files Claude creates are owned by you on the Mac.
- **Privacy settings are locked.** The image carries a Claude Code managed settings file
  that turns off telemetry, error reporting, feedback surveys, and auto-updates. Managed
  settings outrank every project and user setting.

## Known limitations

- **The isolation is for files, not the network.** The VM has full outbound access: the
  internet, your local network, and any service on the Mac that listens on all
  interfaces. Services bound to `127.0.0.1` are not reachable.
- **The tokens are readable inside the VM.** Anything running in the VM can read the
  Claude and GitHub tokens from the environment. Revoke them in your Claude and GitHub
  account settings if needed.
- **Claude can still damage the project**, including `.git`. Commit before long
  unattended sessions.
- **No Xcode.** The VM is Linux.
- **No image paste.** The VM can't see your clipboard.
