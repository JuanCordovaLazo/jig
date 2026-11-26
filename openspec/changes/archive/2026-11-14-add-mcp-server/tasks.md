# Tasks

## 1. The package

- [x] 1.1 Create `packages/jig_mcp` with its pubspec, add it to the workspace list, and verify `dart pub get` resolves it

## 2. The protocol

- [x] 2.1 Add the JSON-RPC framing (parse a line, answer an id, ignore a notification) and unit-test it
- [x] 2.2 Add the server: `initialize`, `tools/list`, and `tools/call` for every verb, with app failures as `isError: true` content, and unit-test each against a fake `JigVerbs`

## 3. Ship it

- [x] 3.1 Add the stdio entry point and verify it answers `initialize` and `tools/list` when fed messages on stdin
- [x] 3.2 Add the new suite to `tool/verify.sh` and `.github/workflows/ci.yml`, document the server in `README.md` and `docs/HANDOFF.md`, then run `./tool/verify.sh` and confirm `All checks passed.`
