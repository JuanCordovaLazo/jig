# Proposal

## Why

Two failures made the MCP server unusable in a real editor, and both were invisible to the
test suite: a handshake that waited on the transport (134 seconds, so every client gave up and
reported a server that "never became ready"), and a handler exception that unwound the stdio
loop and killed the process. The unit tests call `JigMcpServer.handle` with maps, which is the
right way to test the protocol layer and cannot see either - they are properties of the
spawned process.

The cost of not having this check was a whole session of diagnosis where the reported symptom
pointed at the protocol rather than at the ordering.

## What Changes

- `tool/mcp_smoke.dart`: spawns `dart run jig_mcp:jig_mcp` and speaks stdio JSON-RPC to it,
  with no app, no device and no session file. Seven asserts:
  - `initialize` answers within 3s while the configured URI is a socket that never replies;
  - the reply carries `instructions`;
  - `tools/list` serves the expected surface;
  - every tool the instructions name is served;
  - `connect` to a closed port is an `isError` result carrying `NOT_CONNECTED`, not a
    JSON-RPC error and not a crash;
  - the server still answers afterwards;
  - it exits `0` when stdin closes.
- `tool/verify.sh` and `ci.yml` run it, so the gate and CI stay in step.
- `README.md` gains the log line that tells the two failure modes apart (`connected (ready)`
  vs `connected (starting)`), and `docs/HANDOFF.md` records why the check exists.

Out of scope: driving a real editor. That is a host property, not a server one, and an
end-to-end UI test would be a flaky red that says nothing actionable.

## Capabilities

No spec-level change: no requirement about behaviour changes. `skip_specs: true`.

## Impact

`tool/` (one script), `tool/verify.sh`, `.github/workflows/ci.yml`, `README.md`,
`docs/HANDOFF.md`.
