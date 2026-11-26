# Tasks

## 1. Run it for real

- [x] 1.1 Launch the fixture on the emulator and run every read verb (`ping`, `tree`, `snapshot`, `nav`, `events`, `audit`) against it, confirming each answers from the live app
- [x] 1.2 Verify the defect class on device: a tap on an element covered by a dialog fails `ELEMENT_NOT_VISIBLE` instead of reporting `ok`

## 2. Fix what the device exposes

- [x] 2.1 Fix the scenario runner reading `data['state']` instead of the `values` list the app sends, and make the fake mirror the real payload including the `error` branch
- [x] 2.2 Record `back` steps, which have no selector and were being dropped silently
- [x] 2.3 Make the MCP server exit when stdin closes, disposing the connection first
- [x] 2.4 Emit `Jig.uninstall()` in a generated `integration_test`, so the app's semantics handle does not outlive the test

## 3. Prove it end to end

- [x] 3.1 Run a scenario on the device to a green report, and a recorded scenario that replays
- [x] 3.2 Drive the live app through the MCP server: `initialize`, `tools/list`, `ping`, `tap`, a covered tap as `isError`, `back`, `state`, and an unknown tool as a JSON-RPC error
- [x] 3.3 Run the exported `integration_test` on the emulator and confirm it passes
- [x] 3.4 Make the example scenarios self-contained (start from home, wait for what they act on) and document the pattern

## 4. Keep the docs honest

- [x] 4.1 Make `README.md` describe what exists (MCP runs, scenarios run, milestones updated) and add project-scoped VS Code MCP instructions plus `.vscode/mcp.json`
- [x] 4.2 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
