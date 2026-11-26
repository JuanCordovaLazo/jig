# Proposal

## Why

A real agent session, driving the fixture through VS Code, could not use the MCP server at
all. The process started, its stderr log stayed empty, and the host reported it as
`connected (starting)` while every other server reached `connected (ready)` - so not one
`jig` tool was registered in the session.

Reproduced: with a session file pointing at a host that neither accepts nor refuses, the
server took **134 seconds** to answer `initialize`. The connect ran before the stdio loop, so
the handshake waited on the socket. The client's own deadline fired first, and its report
named a symptom that says nothing about the cause.

The same session found no way to attach without the CLI, because the MCP server had no tool
for it.

## What Changes

- Connecting is deferred to the first tool call (`JigLazyVerbs`), so `initialize` and
  `tools/list` answer in 0.2s whatever the transport is doing.
- `JigConnection.attach` takes a timeout (default 10s) instead of inheriting an unbounded
  socket connect - the CLI was affected too.
- A failed connect is not cached, so an app relaunched under a running editor is picked up
  on the next call.
- New `connect` tool: takes a `ws://` URI and rebinds the server, which is the only way a
  client that cannot set a working directory reaches an app.
- An exception from any handler becomes an `isError` tool result instead of escaping the
  stdio loop; the loop itself answers a JSON-RPC error rather than dying.
- `packages/jig_mcp/test/lazy_test.dart` covers the ordering, the retry, the connect tool and
  the containment.

Out of scope: the fixture findings that are not MCP defects (a slider has no verb, `/slidable`
is not reachable from the home list, long-press has no fallback).

## Capabilities

No spec-level change; the verbs are untouched. `skip_specs: true`.

## Impact

`packages/jig_driver` (attach timeout), `packages/jig_mcp` (new `lazy.dart`, `connect` tool,
error containment, tests), `README.md`, `docs/CONTRACT.md`.
