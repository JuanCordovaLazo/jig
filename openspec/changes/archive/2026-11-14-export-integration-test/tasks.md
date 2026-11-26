# Tasks

## 1. The exporter

- [x] 1.1 Add `packages/jig_cli/lib/src/exporter.dart`: emit a self-contained `integration_test` from a scenario, and unit-test the emitted source for each verb plus the refusal cases
- [x] 1.2 Verify the refusal is specific: a scenario with `events` names that step and exports nothing

## 2. Make it compile for real

- [x] 2.1 Add `integration_test` to `apps/fixture`, export a committed example scenario into `apps/fixture/integration_test/`, and verify `flutter analyze` passes there

## 3. Ship it

- [x] 3.1 Add the `export` command (`--scenario`, `--out`, `--entry`) and usage text, document it in `README.md`, and update the verb counts
- [x] 3.2 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
