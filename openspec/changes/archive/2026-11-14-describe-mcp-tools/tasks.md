# Tasks

## 1. Say what the tools are for

- [x] 1.1 Rewrite every tool description to carry purpose, requirement, result and the
      error a caller will hit; verify `dart test packages/jig_mcp` still passes.
- [x] 1.2 Document every argument and turn the closed sets into enums (`scroll.axis`,
      `events.sources`, `swipe.direction`); verify the published `tools/list` JSON in
      `apps/fixture` shows the enums.

## 2. Say what a call needs

- [x] 2.1 Add `tap`'s missing `ref` and `long`, declare `type.value` required, and express
      the selector constraint as `anyOf` over the accepted spellings; verify by dumping
      `tools/list` from a spawned server and reading `tap.inputSchema`.
- [x] 2.2 Confirm a call that omits a selector is still a JSON-RPC `invalid params` and not
      a tool error; verify with the existing `server_test.dart` case.

## 3. Keep it true

- [x] 3.1 Add `tools_contract_test.dart` asserting description length, documented
      arguments, the one-of arms, the enums, the required argument and the named failure
      mode; verify it fails when a description is deleted.
- [x] 3.2 Correct `README.md` ("one tool per verb" was not true) and add the rule to
      `docs/CONTRACT.md`; verify `./tool/verify.sh` passes with 143 tests.

## Workflow follow-up

- Archive the change once the gate is green.
