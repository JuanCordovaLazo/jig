# Copilot instructions

Read `AGENTS.md` and `CONTRIBUTING.md`. They apply to every change in this
repository, which is a Dart pub workspace.

The three rules that break things silently:

- Never edit a `version:` field, a `jig_*` constraint, `jigVersion` or a changelog
  section by hand. `dart run melos version` owns them.
- Commit subjects decide the next version: `fix:` patch, `feat:` minor, `feat!:`
  major. They are load-bearing, not decoration.
- Run `./tool/verify.sh` before pushing.

Never `git push --mirror`, and never move a published tag.
