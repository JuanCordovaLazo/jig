## 1.0.0

The vertical slice runs end to end: the wire contract, the app-side runtime, the
GetX adapters, the driver, the CLI, the scenario runner and the MCP server.
Twenty-three CLI verbs over eleven VM service extensions, exercised on a device
against the conformance fixture.

- `jig_protocol`: selectors, elements, events, responses and error codes. The wire
  protocol version is `1`; it moves to `2` only when a wire change breaks existing
  consumers.
- `jig_flutter`: event bus, semantics-driven element index, diagnostic extensions,
  and the log and error taps.
- `jig_getx`: `JigConnect` HTTP tracing. Navigation needs no adapter:
  `Jig.navigatorObserver` is a plain `NavigatorObserver`.
- `jig_driver` / `jig_cli`: VM service transport, the `jig` command, scenario
  `run`/`record`/`export`, and `audit`.
- `jig_mcp`: Model Context Protocol server over stdio.
- `apps/fixture`: GetX conformance app that reproduces the failure modes of
  existing harnesses.

Verified on Android 17 (API 37) with Flutter 3.47.7: every verb, a scenario, a
recording, an exported `integration_test`, and the MCP server. iOS is not
supported yet.

From this release the workspace is versioned as one: every package shares the
version, and a tag `vX.Y.Z` names them all. Consumers install by git ref and
override the sibling packages, as `README.md` documents.
