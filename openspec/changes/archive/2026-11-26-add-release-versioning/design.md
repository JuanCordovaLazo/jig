# Design

## Context

See `proposal.md` for motivation. Constraints that shape the approach:

- Seven workspace members resolved by one `pubspec.lock`; the workspace is already
  atomic, so versioning it atomically costs nothing extra.
- Consumers install by git ref. Nothing is on pub.dev, so a tag is the only address
  and a transitive dependency of a git dependency resolves against pub.dev unless
  the consumer overrides it.
- The history is a single non-conventional commit with no tags.
- `melos` is already a dev dependency of the workspace.

## Goals / Non-Goals

**Goals:** one version and one tag per release, no value that can drift from the
pubspecs, and a gate that fails a tag that disagrees with them.

**Non-Goals:** publishing, signing, or changing any verb or wire shape.

## Decisions

**melos in fixed mode with `workspaceTag`, over a hand-rolled script.** The
workspace already handles linking, so melos is not needed for resolution; its
remaining job is the arithmetic - seven pubspecs and twelve internal constraints in
one operation, with `dependentConstraints` on by default. A script would have to
reimplement the dependent-constraint rewrite, which is the part most likely to be
subtly wrong. Fixed mode over independent: the workspace is already atomic, and
independent versioning would still need six changelogs plus per-package tags.

**The 1.0.0 cut is deliberately not fully automated.** melos derives changelogs from
Conventional Commits since the last tag, and a single non-conventional commit gives
it nothing to group. The root and the six package changelogs for 1.0.0 are written
by hand, and the cut runs with `--no-changelog`. It also runs
`--no-git-commit-version`, because the `preCommit` hook only runs on melos' own
commit path and, without generated changelogs, melos stages neither them nor the
hand-written ones. Commit and tag for the first release are made by hand. From
1.0.1, with conventional history, melos owns the commit, the changelogs and the tag.

The version is passed as `--manual-version=jig_protocol:1.0.0` rather than the
positional `<package> <version>` form: the positional form also filters the
workspace, so the lockstep pass would see a single package and bump only that one.
`command.version.dryRun` is accepted in configuration and not honoured by
`melos version` 8.10.1, so the plan is inspected by answering `n` at the prompt,
which happens before any write.

**The release number lives in `jig_protocol` as `jigVersion`.** Both frontends
already depend on that package, so a package for one constant would be overhead.
`tool/stamp_version.dart` rewrites the constant from
`packages/jig_protocol/pubspec.yaml` and stages it, wired to `preCommit`. A
`--dart-define` or a build-time generated file was rejected: the CLI is run from
source in development, so a value that exists only at build time would be missing
exactly when `jig version` is used.

**Protocol 1 is additive forever.** A frontend and a runtime are updated
independently, so the protocol number is the only runtime guard against a mismatch.
Tying it to the package major is what makes `^1.0.0` mean something.

**The guard is a job in `ci.yml`, not a separate workflow.** Adding `tags: ['v*']`
to `on.push` makes the tagged commit run `analyze` and `test` as well, so the tag is
verified whole; a separate workflow would duplicate the pinned toolchain.

## Risks / Trade-offs

- Fixture left out of the lockstep → `dart pub get` fails for the entire workspace
  → `versionPrivatePackages: true`, and give the fixture the `version:` it lacks.
- `preCommit` not staging its own edits → the stamp script runs `git add` itself, and
  the release check fails if the constant disagrees with the tag.
- Hand-written 1.0.0 notes and generated 1.0.1+ notes could diverge in format → the
  guard only requires a section per version; both use the same heading level.
- Two test fixtures hardcode the old protocol string → switch them to the constant so
  they cannot drift again.
