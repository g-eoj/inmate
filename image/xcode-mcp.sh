#!/bin/sh

# Claude's stdio MCP server for Xcode: relays to the bridge inmate runs on the host for
# this session. The address comes from the environment, so .claude.json doesn't change.

if [ -z "${INMATE_XCODE_BRIDGE_ADDR-}" ]; then
  echo "inmate-xcode-mcp: Xcode bridge is off; start with INMATE_XCODE_BRIDGE=1" >&2
  exit 1
fi
exec socat - TCP:"$INMATE_XCODE_BRIDGE_ADDR"
