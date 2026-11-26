# Tasks

## 1. Migrate the file

- [x] 1.1 Replace `apps/fixture/.vscode/mcp.json` with `apps/fixture/.mcp.json` in the
      `mcpServers` format; verify both parse with `python3 -m json.tool`.
- [x] 1.2 Restore `.gitignore` to a plain `.vscode/` and record why `.mcp.json` is tracked;
      verify `git check-ignore -v apps/fixture/.mcp.json` finds nothing and
      `git check-ignore -v apps/fixture/.vscode/probe.txt` reports `.vscode/`.

## 2. Close the gap the migration exposed

- [x] 2.1 Add `resolveServerUri` (`--uri`, then `$JIG_URI`, then session discovery) and use
      it in the bin; verify with `dart test packages/jig_mcp`, including the empty-flag and
      unset-variable cases.
- [x] 2.2 Verify on a real spawn that the environment is honoured: with
      `JIG_URI=ws://127.0.0.1:1/ws` the `ping` tool reports "cannot connect to
      ws://127.0.0.1:1/ws" rather than "No session".

## 3. Document and verify

- [x] 3.1 Rewrite the editor section of `README.md` for the portable format, naming the
      deprecation, the missing `inputs`, `$JIG_URI`, the FVM variant and `tools: ["*"]`;
      verify every JSON snippet parses and none uses the deprecated `servers` key.
- [x] 3.2 Run the exact command from the committed file and confirm `initialize` plus a
      13-tool `tools/list`; verify `./tool/verify.sh` passes with 135 tests.

## Workflow follow-up

- Archive the change once the spawn check and the gate are green.
