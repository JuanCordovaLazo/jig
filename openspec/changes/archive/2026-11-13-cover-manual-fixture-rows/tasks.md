# Tasks

## 1. Cover the in-process rows

- [x] 1.1 Test rows 2 and 10 in `apps/fixture/test` (a tap on a reordering list lands on the named row; `type` then `tap` on the form submits the typed value), and verify with `cd apps/fixture && flutter test`
- [x] 1.2 Test rows 5, 8 and 17 (registered state readers through `JigStateRegistry`; the `since`/`sources`/`limit` window over a high-volume log; an unlabelled `IconButton` reached by type and index), and verify with `cd apps/fixture && flutter test`
- [x] 1.3 Test rows 6 and 7 (a transport failure reaches the event bus as an `error`; the authenticator's retry exposes the final `200` and never the `401`) by driving the loopback `FakeBackend` from a plain `test`, since the widget binding answers every HTTP request with a `400`, and verify with `cd apps/fixture && flutter test`

## 2. Keep the docs true

- [x] 2.1 Move rows 2, 5, 6, 7, 8, 10 and 17 from manual to automated in `docs/fixture-matrix.md`, and update the test count in `docs/HANDOFF.md`, then verify the file names cited in the matrix exist
- [x] 2.2 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
