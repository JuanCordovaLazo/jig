# Tasks

## 1. The check

- [x] 1.1 Write `tool/mcp_smoke.dart`: spawn, handshake under a budget against a socket that
      never replies, tool list, playbook names, refused `connect`, survival, clean exit;
      verify a green run in about two seconds.
- [x] 1.2 Reintroduce the handshake ordering and the escaping exception one at a time and
      confirm each fails with the intended message, then restore both.

## 2. Put it where it cannot be skipped

- [x] 2.1 Add it to `tool/verify.sh` and to the `test` job in `ci.yml`; verify
      `./tool/verify.sh` reports the `mcp smoke (wire)` section and still ends with
      `All checks passed.`

## 3. Make the diagnosis cheap

- [x] 3.1 Document in `README.md` which log line separates "the server did not hand shake"
      from "the host did not offer the tools", and record the reason for the check in
      `docs/HANDOFF.md`.

## Workflow follow-up

- Archive the change.
