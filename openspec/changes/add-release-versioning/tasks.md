# Tasks

## 1. Workspace versioning

- [ ] 1.1 Keep `melos` as a root dev dependency and add the version config (`mode: fixed`, `workspaceTag: true`, `versionPrivatePackages: true`, `changelogFormat/groupByType: true`, `preCommit` hook). Verify with `dart run melos list` that all seven members are discovered.
- [ ] 1.2 Give `apps/fixture` the `version:` field it lacks, matching the current workspace version. Verify `dart pub get` at the root still resolves.
- [ ] 1.3 Prove the cut before running it: run `dart run melos version --manual-version=jig_protocol:1.0.0 --no-changelog` and answer `n`. melos prints the whole plan before touching anything, and the positional package form would filter the workspace to one package, so `--manual-version` is the form that applies the version to all seven members. Confirm all seven and the twelve internal constraints are covered.

## 2. One reported version

- [ ] 2.1 In `jig_protocol`, add `jigVersion` and set `jigProtocolVersion` to `'1'`. Verify `dart test` in `packages/jig_protocol`.
- [ ] 2.2 Report `jigVersion` from `jig version` and from the MCP `serverInfo.version` instead of the literals. Verify `dart test` in `packages/jig_cli` and `packages/jig_mcp`.
- [ ] 2.3 Point the two test fixtures that hardcode `'0.1'` at `jigProtocolVersion`. Verify both suites still pass.
- [ ] 2.4 Add `tool/stamp_version.dart` and wire it to `preCommit`. Verify by running it and checking `git status` reports the rewritten constant as staged, then restore it.

## 3. Release notes

- [ ] 3.1 Rewrite the root `CHANGELOG.md` for `1.0.0` from the milestone table, dropping the pre-alpha claim. Verify `grep -n '^## 1.0.0' CHANGELOG.md` matches and no "not written yet" claim remains.
- [ ] 3.2 Create a `CHANGELOG.md` per package with a `1.0.0` section. Verify `grep -c '^## 1.0.0' packages/*/CHANGELOG.md` reports one for each of the six.

## 4. Release gate

- [ ] 4.1 Put the check in `tool/check_release.sh` (tag argument, non-zero on mismatch) and add the `release-guard` job plus `tags: ['v*']` to `ci.yml`. Verify the script exits non-zero for a wrong tag and zero for `v1.0.0` once the versions are bumped.
- [ ] 4.2 Confirm the existing `analyze` and `test` jobs stay unchanged and that `tool/verify.sh` mirrors them. Verify `./tool/verify.sh` still passes.

## 5. Documentation

- [ ] 5.1 Write the protocol rule in `docs/CONTRACT.md`: additive keeps protocol 1 with a minor bump, breaking moves to protocol 2 with a major bump. Verify the file names both branches.
- [ ] 5.2 Fix the README install snippet with the `dependency_overrides` block and update the status line. Verify by resolving a throwaway consumer against the tag in `/tmp`, which must run `dart pub get` cleanly.
- [ ] 5.3 Add the release procedure and the identity convention to `CONTRIBUTING.md`. Verify the documented commands match what section 6 actually runs.

## 6. Cut 1.0.0

- [ ] 6.1 Run the cut: `dart run melos version --manual-version=jig_protocol:1.0.0 --no-changelog --no-git-commit-version --yes`, then `dart run tool/stamp_version.dart`. Verify the seven pubspecs read `1.0.0`, the twelve constraints read `^1.0.0`, and the constant reads `1.0.0`.
- [ ] 6.2 Run `./tool/verify.sh` and confirm every step passes on the bumped workspace.
- [ ] 6.3 Commit, tag `v1.0.0` annotated, push with `--follow-tags`. Verify `git ls-remote --tags origin` shows the annotated tag and that `tool/check_release.sh v1.0.0` passes on a fresh clone.

## Workflow follow-up

- Archive the change once the release is published and the gate has run on the tag.
