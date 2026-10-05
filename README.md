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
3. Logs you in to Claude if no token is stored, via a browser URL and a code.
4. Asks for a GitHub token if none is stored. Press Enter to skip.

Both tokens live in the macOS Keychain. Run `inmate setup` again to update Claude Code.
To log in again or replace a token, delete the Keychain item first:

```sh
security delete-generic-password -s inmate -a claude-code-oauth-token
security delete-generic-password -s inmate -a github-token
```

Everything after `inmate` is passed through untouched:

```sh
inmate claude                 # Claude Code in the VM
inmate claude --continue      # Claude's own flags work as usual
inmate bash                   # a shell in the VM
```

If no Claude token is stored, `inmate` refuses to start and tells you to run
`inmate setup`. Claude never shows its own login screen inside the VM.

The VM gets 4 CPUs and up to 8 GB of memory by default. Memory is a ceiling, not a
reservation: the host only commits what the VM actually uses. Override either with an
environment variable:

```sh
INMATE_MEMORY=4G inmate claude
```

`INMATE_CPUS` works the same way. Memory takes a `K`, `M`, `G`, or `T` suffix.

## GitHub

Inside the VM, `gh` and HTTPS git remotes use the token from `inmate setup`. SSH remotes
do not work: the VM has no SSH keys.

Anything running in the VM can read the token, so scope it to the repos you work on:

1. On GitHub, open Settings → Developer settings → Personal access tokens → Fine-grained
   tokens.
2. Under Repository access, choose "Only select repositories" and pick your repos.
3. Under Permissions, grant Contents: Read and write. Add Pull requests and Issues if
   you want `gh pr` and `gh issue`.
4. Run `inmate setup` and paste the token when asked.

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
MCP server:

```sh
npx -y supergateway --stdio "xcrun mcpbridge" --port 8765 --outputTransport streamableHttp
```

Then add it to `.mcp.json` as above, with port 8765. The bridge listens on all
interfaces with no authentication. While it runs, the VM and anything else on your local
network can drive Xcode on your Mac through it. That is a deliberate hole in the
isolation. Stop the bridge when you are done.

## Claude settings

The image carries two kinds of Claude Code settings.

**Managed settings** (`image/managed-settings.d/`) are policy. They outrank every project
and user setting and can't be changed from inside the VM. The one shipped here turns off
telemetry, error reporting, feedback, nonessential traffic, and auto-updates.

**User defaults** (`image/defaults.d/`) are opinionated examples, meant to be edited or
deleted before you build. The `*.json` files are merged in name order into one user
settings file, which is copied to `<project>/.inmate/home/.claude/settings.json` the
first time you run `inmate` in a project and never again. The shipped examples set:

- `10-inmate-models.json`: Opus, xhigh effort, high effort for Fable
- `20-inmate-plugins.json`: three official plugins
- `90-inmate-misc.json`: vim editor mode, no commit or PR attribution

To change the defaults, edit or remove the files and run `inmate setup`. To reseed a
project, delete its `settings.json`.

## Cleaning up

Each run creates a container that is removed when the command exits. If a terminal dies
mid-session, the container can be left behind:

```sh
container ls -a                 # names start with inmate-
container rm -f <name>
```

`inmate setup` starts the `container` background service, which keeps running after you
exit. To stop it:

```sh
container system stop
```

The next `inmate` run starts it again.

`container` keeps a build cache in a separate builder VM that grows with every image
build and is never trimmed. Check with `container system df` and reclaim the space with:

```sh
container builder delete --force
```

The next `inmate setup` recreates it.

## How it works

- **Same paths.** The project is mounted at the same absolute path inside the VM, so
  file paths match what you see on your Mac.
- **Fresh VM, persistent state.** Each run starts a new VM. `HOME` is
  `<project>/.inmate/home`, so Claude's config, history, and tool caches persist per
  project. Git ignores `.inmate/` without changes to your own ignore files.
- **Root inside the VM.** `container` mounts have no UID mapping, so every file appears
  root-owned inside the VM. Files Claude creates are owned by you on the Mac.

## Known limitations

- **The isolation is for files, not the network.** The VM has full outbound access: the
  internet, your local network, and any service on the Mac that listens on all
  interfaces. Services bound to `127.0.0.1` are not reachable.
- **The tokens are readable inside the VM.** Anything running in the VM can read the
  Claude and GitHub tokens from the environment.
- **Claude can still damage the project**, including `.git`. Commit before long
  unattended sessions.
- **No Xcode.** The VM is Linux.
- **No image paste.** The VM can't see your clipboard.
