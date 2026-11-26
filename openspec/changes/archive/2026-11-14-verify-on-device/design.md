# Design

## Context

See proposal.md. The device is an Android 17 / API 37 x86_64 emulator (`emulator-5554`),
Flutter 3.47.7. `jig launch` runs `flutter run --machine` and publishes
`apps/fixture/.jig/session.json`.

## Decisions

1. **Assert against the wire, not against the fake.** The runner's `state` bug survived a
   green suite because the fake returned the shape the runner expected. Fakes here are now
   copied from a real response (`{count, values: [{name, value|error, type}]}`), including
   the `error` branch a registered-but-throwing reader produces.

2. **A verb that refuses is working, not broken.** Typing into a field that the route
   transition had not built yet failed with `ELEMENT_NOT_EDITABLE`, which is the correct
   answer. The fix belongs in the scenario - `wait` before acting - not in the verb, and
   the pattern is documented rather than papered over with a retry inside `type`.

3. **The generated test owns the app's lifecycle.** `Jig.install()` registers extensions
   and takes a semantics handle; a test that calls `app.main()` must call
   `Jig.uninstall()`, or the run fails on Flutter's end-of-test check. The exporter emits
   that teardown because the generated file is the thing that started the app.

4. **An MCP server exits when its stdin closes.** Newline-delimited JSON-RPC over stdio
   ends at EOF; keeping a WebSocket open past it leaves a subprocess that never dies. The
   entry point disposes the connection and exits.

5. **The MCP surface stays a client of the verbs.** Eleven tools, one per verb, no new
   extension. Verified on device: a tap behind a modal comes back `isError: true` with
   `ELEMENT_NOT_VISIBLE`, and an unknown tool is a JSON-RPC `-32602` naming the real ones.
