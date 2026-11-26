# Tasks

## 1. Protocol surface

- [x] 1.1 Add `CLEAR_REFUSED` to `JigErrorCode` and document it in `docs/CONTRACT.md`'s
      error table; verify with `dart test packages/jig_protocol` and
      `dart run jig_cli:jig --help` still listing every verb.

## 2. `clear`, from the app to the CLI

- [x] 2.1 `JigActions.clearText` handles `clear` on the existing `ext.jig.type`
      extension: resolve as `type` does, dispatch `setText('')`, wait a frame, re-read
      the value, and fail `CLEAR_REFUSED` naming what is left; verify with a fixture
      widget test that types into `name_field`, clears it, and sees both the field and
      a new `form.name` reader empty.
- [x] 2.2 Driver `JigVerbs.clear`/`JigConnection.clear` and the CLI verb `clear`, with
      `type` rejecting an empty `--value` as a usage error that names `clear`; verify
      `jig clear --key name_field` returns `ok` on the emulator and
      `jig type --key name_field -v ''` exits `2` with that hint.
- [x] 2.3 `clear` as a scenario step, a recorded verb, and an exported
      `JigActions.clearText` call; verify with `dart test packages/jig_cli` and by
      running a recorded scenario that clears a field.
- [x] 2.4 Document the verb in `README.md`'s reference table and the `type` empty-value
      rule; verify the documented commands run as written against the emulator.

## 3. `screenshot`, from the app to a file

- [x] 3.1 Register an eleventh extension `ext.jig.screenshot` over the root
      `OffsetLayer`, returning PNG base64 plus dimensions at the requested pixel ratio;
      verify with a fixture widget test that decodes the PNG signature, checks the
      dimensions match the request, and that the payload is not a uniform image.
- [x] 3.2 Driver method and CLI verb `screenshot` with `-o/--out` and `--pixel-ratio`,
      defaulting to `.jig/screenshot-<seq>.png` beside the session; verify on the
      emulator that the command exits `0` and the written file opens as the fixture's
      current screen.
- [x] 3.3 Document the verb, the extension row and the file default in `README.md` and
      `docs/CONTRACT.md`; verify the README command reproduces the emulator run.

## 4. MCP tools

- [x] 4.1 `clear` tool over `JigVerbs.clear`; verify with `dart test packages/jig_mcp`
      and a live `tools/call` against the emulator.
- [x] 4.2 `screenshot` tool returning an `image` content block plus a text block with
      the dimensions; verify the live response's `image.data` decodes to a PNG of the
      reported size.
- [x] 4.3 Document both tools and the image result in `README.md`'s MCP section;
      verify the documented `tools/list` output matches the server.

## 5. Fixture wiring

- [x] 5.1 Add `apps/fixture/.vscode/mcp.json` and the `.gitignore` exception that lets
      it be tracked; verify `git check-ignore -v apps/fixture/.vscode/mcp.json` finds
      nothing, `git status` shows the file, and the JSON parses.
- [x] 5.2 Add the `form.name` reader and the matrix rows these verbs prove; verify
      with `flutter test` in `apps/fixture` and a device pass over the new rows.

## 6. Whole-system verification

- [x] 6.1 `./tool/verify.sh` passes, and a device session exercises `clear`,
      `screenshot`, both MCP tools and the MCP server started from
      `apps/fixture/.vscode/mcp.json`'s configuration.

## Workflow follow-up

- Archive the change once the device pass is recorded in `docs/HANDOFF.md`.
