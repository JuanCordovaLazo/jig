# Tasks

## 1. Make the event recordable

- [x] 1.1 Add `selectorSpec` (the structured selector) beside the existing `selector` sentence in `jig_flutter`'s verb event, and verify the old field is unchanged

## 2. Convert events into a scenario

- [x] 2.1 Add `packages/jig_cli/lib/src/recorder.dart`: turn verb events into scenario steps, count the events it cannot convert, and unit-test it over synthetic events including the skip case

## 3. Ship it

- [x] 3.1 Add the `record` command (`--since`, `--out`, `--name`) and usage text, and verify a recorded file parses back through `JigScenario.parse`
- [x] 3.2 Document `record` in `README.md` and update the verb counts in `docs/HANDOFF.md` and `CONTRIBUTING.md`
- [x] 3.3 Run `./tool/verify.sh` and confirm it reports `All checks passed.`
