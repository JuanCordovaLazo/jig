# Tasks

## 1. The action and the wire

- [x] 1.1 Add `JigActions.adjust` (read, refuse at the end, step, read back, refuse a stall)
      and the downward lookup a keyed range control needs; verify with the fixture widget
      tests.
- [x] 1.2 Route `action=increase|decrease` through `ext.jig.tap`; verify the extension count
      is still eleven and `dart analyze` is clean.

## 2. Every entry point

- [x] 2.1 Driver `adjust`, the CLI verb with `--direction`/`--times`, the scenario step, the
      recorded event and the exported `JigActions.adjust` call; verify with
      `dart test packages/jig_cli`.
- [x] 2.2 The MCP tool, with the failure mode named in its description; verify with
      `dart test packages/jig_mcp`, whose contract test covers it.

## 3. Prove it on a device

- [x] 3.1 `jig adjust --key rating_slider --times 2` returns `value: "100%"` and the reader
      `form.rating` agrees; a further step up fails `ADJUST_REFUSED` naming the maximum, and
      `adjust --key submit` fails naming the missing action.
- [x] 3.2 The same through MCP after `connect`, including the refusal past the maximum.

## 4. Document and close

- [x] 4.1 README table and examples, the CONTRACT error and extension rows, the fixture matrix
      row, and the known `find --key` gap in `docs/HANDOFF.md`; verify `./tool/verify.sh`
      passes with 168 tests.

## Workflow follow-up

- Archive the change.
