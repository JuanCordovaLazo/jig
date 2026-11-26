# Agent notes

Read `CONTRIBUTING.md` before changing anything: it holds the procedure. This file
holds only the rules that are cheap to break and expensive to discover, and that no
script in the repository can enforce.

## Versions and releases

- Do not edit a `version:` field, an internal `jig_*` constraint, `jigVersion` in
  `jig_protocol`, or a `CHANGELOG.md` section by hand. `dart run melos version`
  owns all four.
- melos runs only to cut a release. A normal change does not need it: `dart pub get`
  resolves the workspace.
- The commit subject decides the next version: `fix:` patch, `feat:` minor,
  `feat!:` or `BREAKING CHANGE:` major. `docs:`, `chore:`, `test:`, `ci:` and
  `refactor:` bump nothing on their own.
- A published tag is never moved, deleted or re-pointed. A defect in a released
  version becomes a new patch release.
- A breaking wire change moves `jigProtocolVersion` to the next integer and takes a
  major package bump; an additive change leaves it at `1` and takes a minor bump.
  See `docs/CONTRACT.md`.
- Every workspace member carries a `version:` and shares it with the rest. A member
  without one breaks `dart pub get` for the whole workspace.

## Before pushing

- `./tool/verify.sh` must pass: analysis, every suite, and the MCP smoke test.
- On a release tag, `./tool/check_release.sh vX.Y.Z` must pass. That is exactly what
  CI runs on the tag.

## Do not

- `git push --mirror`. It would publish the local `refs/agents/*` checkpoints, which
  are session state and not part of the project.
- Re-tag, move or force-push a version that is already public.
- Restate the release procedure here. If the procedure changes, it changes in
  `CONTRIBUTING.md`.
