# Tasks

## 1. Reproduce and bound

- [x] 1.1 Reproduce the stall with a session file pointing at an unroutable host, measure
      the `initialize` latency before and after, and confirm it drops from ~134s to ~0.2s.
- [x] 1.2 Add a timeout to `JigConnection.attach` and confirm a dead-session tool call fails
      in 10s with `no answer within 10s` rather than hanging.

## 2. Defer the connection

- [x] 2.1 Add `JigLazyVerbs` (connect on first use, cache success, retry failure) and use it
      in the bin; verify with `dart test packages/jig_mcp`.
- [x] 2.2 Confirm `initialize` and `tools/list` never touch the transport, including with a
      session file present.

## 3. Make it usable without the CLI

- [x] 3.1 Add the `connect` tool and verify the whole flow against a live app with the
      session file deleted: `ping` → `NOT_CONNECTED`, `connect` → attached, `tree` and
      `screenshot` working.
- [x] 3.2 Contain handler exceptions so they become `isError` results and the loop survives;
      verify with a deliberately throwing fake and with a refused `connect`.

## 4. Document and close

- [x] 4.1 Document the deferred handshake and `connect` in `README.md` and
      `docs/CONTRACT.md`, and name `connect` in the server instructions; verify the
      instructions test still passes.
- [x] 4.2 Verify `./tool/verify.sh` passes with 159 tests.

## Workflow follow-up

- Archive the change; the non-MCP fixture findings are reported, not fixed here.
