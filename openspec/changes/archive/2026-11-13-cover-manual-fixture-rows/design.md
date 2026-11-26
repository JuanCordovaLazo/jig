# Design

## Context

See proposal.md. The harness from the previous change (`pumpPage`, `withPage`,
`drive`, `driveFailure`) covers every row here except the two that need a socket.
Rows 2, 5, 8, 10 and 17 are pure widget and state work; 6 and 7 drive a real HTTP
server on loopback through `JigConnect`.

## Decisions

1. **Rows 6 and 7 are plain `test`s, not `testWidgets`.** `TestWidgetsFlutterBinding`
   installs an `HttpOverrides` that answers every request with `400` and never
   opens a connection, so a widget test can only ever observe that mock. A probe
   that looked like a working loopback call was the mock answering: the status was
   a real `400` from the binding, not from the fixture's server. A plain `test`
   leaves the binding uninitialised, so `FakeBackend` is a real socket. Neither row
   needs a frame, because both are about what leaves the call rather than what is
   on screen.

2. **Row 6 asserts the transport shape, not a failure code.** `GetConnect` reports a
   timeout as a response with no body and no status, so `ApiController` records
   `slow: null` and no exception is thrown. A tracing layer hooked to response
   modifiers would therefore see a success and report nothing. The test asserts the
   bus carries an `error` for the exchange, that no `response` is recorded, and that
   the recorded status is null - the last one so that a future change which starts
   inventing a status is caught.

3. **Row 2 asserts the invariant, not the absence of a coordinate path.** A test
   cannot demonstrate "a stale position would have been wrong" without injecting
   one. What it can assert is the property that makes the claim true: with the list
   actively reordering, `tap(key: row_3)` invokes the handler for id 3 and not for
   whichever row happens to occupy that slot. That is the behaviour a user depends
   on, and it fails if selection is ever resolved from a cached position.

4. **Row 17 taps by widget type and index on purpose.** The control has no label,
   which is the row's subject; asserting that `Semantics` is missing would test the
   fixture, not the harness. The test asserts that the type-plus-index selector
   still reaches it, so the documented workaround is real.

5. **No production seam.** All seven rows are reachable through `JigActions`,
   `JigElementIndex`, `JigBus` and `JigStateRegistry`, which are already public.
