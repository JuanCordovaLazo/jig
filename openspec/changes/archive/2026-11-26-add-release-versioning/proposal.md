# Proposal

## Why

The repository is about to become public with no versioning or tagging convention,
and the tag is the only way to install anything: consumers depend on a package by
git ref, since nothing here is published to pub.dev. A tag that disagrees with the
pubspecs therefore installs code that is not the release it names. Today the version
lives in three places that already drift - the pubspecs, two string literals in
Dart, and the tag - and `jigProtocolVersion` has no rule for when it moves.

## What Changes

- Adopt `melos` as a dev dependency in `fixed` mode with `workspaceTag: true`: one
  annotated tag `vX.Y.Z` per release names every package at once.
- Release `1.0.0` across the workspace: seven pubspecs and the twelve internal
  constraints. The fixture gains a `version:` it does not have and joins the
  lockstep, because a stale constraint breaks `dart pub get` for the whole
  workspace.
- Add `jigVersion` to `jig_protocol` as the single source of the release number.
  `jig_cli` and `jig_mcp` report it instead of a hardcoded literal, and
  `tool/stamp_version.dart` rewrites it from the pubspec during a release.
- `jigProtocolVersion` moves from `0.1` to `1`, with the missing rule written down:
  an additive wire change is a minor bump and keeps protocol 1; a breaking one
  moves to protocol 2 and a major package bump.
- Rewrite the changelog for `1.0.0`: the root narrative plus one `CHANGELOG.md` per
  package, all written by hand for this cut because a single-commit history gives
  Conventional Commits nothing to group. From `1.0.1` melos generates them.
- Correct the README install snippet. A git-ref dependency resolves its own
  dependencies against pub.dev, where these packages do not exist, so the snippet
  needs `dependency_overrides` for the sibling packages.
- Add a `release-guard` CI job on `v*` tags: every pubspec version, every package
  changelog and the root changelog must agree with the tag.

Out of scope: publishing to pub.dev, signing tags, and any change to the verbs or
wire shapes.

## Capabilities

### New Capabilities

- `release`: how a version is chosen, where it is recorded, what a tag promises,
  and how the wire protocol version moves relative to the package version.

### Modified Capabilities

<!-- none: no existing requirement changes -->

## Impact

Root `pubspec.yaml` (melos dependency and config), the seven package and app
pubspecs, `packages/jig_protocol/lib/jig_protocol.dart`, the version reporting in
`jig_cli` and `jig_mcp`, two test fixtures that hardcode the old protocol string,
`.github/workflows/ci.yml`, `CHANGELOG.md` and six new per-package changelogs,
`README.md`, `CONTRIBUTING.md`, `docs/CONTRACT.md`, and the new
`tool/stamp_version.dart`.
