# Tasks

## 1. Send the playbook

- [x] 1.1 Add `JigMcpServer.instructions` and include it in the `initialize` result; verify
      by spawning the server from `apps/fixture` and reading the first reply line.
- [x] 1.2 Point `screenshot`'s description at `tree` and `state`, for a caller that reads
      descriptions but not the playbook; verify `dart test packages/jig_mcp` passes.

## 2. Keep the playbook true

- [x] 2.1 Add `instructions_test.dart` covering the presence, the cost ranking, the
      "not for locating an element" sentence, and that every backticked name is a real tool
      or error code; verify a deliberately wrong name fails the test.
- [x] 2.2 Document `instructions` in `README.md` and `docs/CONTRACT.md`; verify
      `./tool/verify.sh` passes with 149 tests.

## Workflow follow-up

- Archive the change once the gate is green.
