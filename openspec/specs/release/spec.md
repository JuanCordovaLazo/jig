# release Specification

## Purpose

Defines how a version is chosen and recorded, what a released tag promises, and how
the wire protocol version moves relative to the package version.

## Requirements

### Requirement: One version covers the workspace

Every workspace member SHALL declare the same version at a released commit, and a
release SHALL be identified by a single annotated tag `vX.Y.Z` whose `X.Y.Z` equals
every member's declared version.

#### Scenario: A release tag names every package

- **WHEN** a version is released
- **THEN** each workspace member's pubspec declares that version, each internal
  dependency constraint allows it, and one annotated tag `vX.Y.Z` points at the
  commit that declares it

#### Scenario: A member without a version cannot be left behind

- **WHEN** a workspace member that other members depend on is excluded from a
  version bump
- **THEN** resolution fails for the whole workspace, so every member must carry a
  version and join the lockstep

### Requirement: A published tag never moves

A release tag SHALL NOT be moved, deleted or re-pointed once it is public, and a
defect in a released version SHALL be corrected by releasing a new patch version.

#### Scenario: Fixing a released defect

- **WHEN** a defect is found in a tagged version
- **THEN** the fix is released under a new tag, and the original tag still resolves
  to the commit it named

### Requirement: Reported versions match the release

Every command and handshake that reports a version SHALL report the release version
declared in the pubspecs, and SHALL NOT report a value maintained separately in
code.

#### Scenario: The CLI reports the release version

- **WHEN** `jig version` runs
- **THEN** the version it prints for the CLI equals the version declared by the
  released pubspecs, without a connection to an app

#### Scenario: The MCP handshake reports the release version

- **WHEN** an MCP client completes `initialize`
- **THEN** the `serverInfo.version` it receives equals the version declared by the
  released pubspecs

### Requirement: The protocol version changes only with breaking wire changes

`jigProtocolVersion` SHALL stay the same when a wire change is additive, and SHALL
increase when a wire change breaks existing consumers. An additive change SHALL take
a minor package bump; a breaking change SHALL take a major package bump.

#### Scenario: An additive change keeps the protocol

- **WHEN** a field, event or verb is added without changing existing shapes
- **THEN** `jigProtocolVersion` is unchanged and the package version takes a minor
  bump

#### Scenario: A breaking change moves the protocol

- **WHEN** a field is renamed or removed, or an existing shape changes meaning
- **THEN** `jigProtocolVersion` increases and the package version takes a major bump

#### Scenario: A mismatched frontend refuses to guess

- **WHEN** a frontend reaches a runtime that declares a different protocol version
- **THEN** it fails with a named error instead of issuing commands against an
  unknown contract

### Requirement: A release is refused when the tag disagrees

Continuous integration SHALL fail a tag push when any workspace member's declared
version, or the release notes for that version, disagree with the tag.

#### Scenario: Version and tag disagree

- **WHEN** a `vX.Y.Z` tag is pushed and any pubspec declares a different version
- **THEN** the release check fails and names the file and the version it found

#### Scenario: Release notes are missing

- **WHEN** a `vX.Y.Z` tag is pushed and a changelog has no section for that version
- **THEN** the release check fails and names the changelog

### Requirement: Every tagged version has release notes

The workspace root changelog and each package changelog SHALL contain a section for
the tagged version, whether written by hand or generated from the commit history.

#### Scenario: A release ships notes

- **WHEN** a version is released
- **THEN** the root changelog describes the release and each package changelog
  carries a section for that version
