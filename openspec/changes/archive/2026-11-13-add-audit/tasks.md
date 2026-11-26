# Tasks

## 1. The auditor

- [x] 1.1 Add `packages/jig_cli/lib/src/audit.dart` with a pure function over `List<JigElement>` that returns the three findings of design.md decision 3 plus counts, and unit-test it in `packages/jig_cli/test/audit_test.dart`
- [x] 1.2 Verify the severity split is real: a control with no label and no key is an error, the same control with a key is only a warning, and a shared label is ambiguous

## 2. The verb

- [x] 2.1 Add the `audit` command (with `--strict` and `--limit`) to `packages/jig_cli/lib/src/cli.dart` and the usage text, wiring it to the existing `tree` call, and unit-test the dispatch in `packages/jig_cli/test/cli_test.dart`
- [x] 2.2 Document the verb in `README.md`, then verify the docs describe the exit codes that the code returns

## 3. Verify

- [x] 3.1 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
