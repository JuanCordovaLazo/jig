# Tasks

## 1. The contract the runner stands on

- [x] 1.1 Add `JigVerbs` to `jig_driver` with the acting and reading verbs, make `JigConnection` implement it, and add `EXPECTATION_FAILED` to the protocol with a line in `docs/CONTRACT.md`, then verify `dart analyze .`

## 2. Parse a scenario

- [x] 2.1 Add `packages/jig_cli/lib/src/scenario.dart`: parse and validate a JSON scenario (unknown verb, missing selector, bad direction), and unit-test the accepted and rejected shapes

## 3. Run a scenario

- [x] 3.1 Add `packages/jig_cli/lib/src/runner.dart`: execute steps over `JigVerbs`, stop at the first failure, mark the rest `skipped`, and evaluate `state.expect`
- [x] 3.2 Unit-test the runner against a fake driver: a scenario that passes, one that fails mid-way with the rest skipped, and an expectation mismatch reporting `EXPECTATION_FAILED`

## 4. Ship it

- [x] 4.1 Add the `run` command and usage text, an example scenario under `apps/fixture/scenarios/`, and a doc block in `README.md` showing the format
- [x] 4.2 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
