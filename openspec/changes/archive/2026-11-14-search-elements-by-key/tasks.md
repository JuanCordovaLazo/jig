# Tasks

## 1. Widen the filter

- [x] 1.1 Include the element key in the `q` predicate in `ext.jig.elements`; verify with
      `flutter test` in `packages/jig_flutter`.
- [x] 1.2 Add a test that a key matches, a label still matches, and an actual miss returns
      `count: 0`.

## 2. Say what it does

- [x] 2.1 Update the CLI help, the MCP schema and the README table to "key, label or value";
      verify `./tool/verify.sh` passes with 160 tests.

## Workflow follow-up

- Archive the change.
