# Spec Delta

## MODIFIED Requirements

### Requirement: Element listings carry the selectors a caller can use

The system SHALL report for every listed element the key it carries, the widget
type that owns it, and its bounds, alongside the label, actions and handle already
reported. A reported key SHALL belong to the node that can act for the widget that
carries it, and SHALL NOT be borrowed from an ancestor. Every handle the listing
reports SHALL be usable by the operations that accept one. Bounds SHALL be
informational only; no operation SHALL accept a caller-supplied position as input.

#### Scenario: A widget carries a key

- **WHEN** a widget provides a key and appears in a listing
- **THEN** the listing reports that key so it can be used as a selector directly

#### Scenario: The keyed widget's node is not the node that acts

- **WHEN** a keyed widget's own node cannot act, and a node covering the identical
  rectangle can, such as a range control or a scrollable
- **THEN** the listing reports the key on the node that acts, so the key it prints is
  the key that works

#### Scenario: A key names a node that cannot act

- **WHEN** a key names a node that carries no actions
- **THEN** the listing still reports it, so a caller that read the key from its own
  source can select with it

#### Scenario: A key the framework gave itself

- **WHEN** a key's value is a private framework identifier rather than a name a caller
  wrote
- **THEN** the listing does not report it

#### Scenario: A widget exposes no label

- **WHEN** an interactive widget is labelled by nothing, such as an icon-only button
- **THEN** the listing still reports its owning widget type, so it remains addressable by type

#### Scenario: A reported handle is used by a gesture

- **WHEN** a caller passes a handle from a listing to a gesture, and no widget owns the
  node behind it, as with a keyless scrollable
- **THEN** the gesture resolves the node's rectangle and acts on the box occupying it
  instead of reporting that nothing owns the handle

#### Scenario: Bounds are read but never supplied

- **WHEN** a caller reads the bounds of an element to reason about a region of interest
- **THEN** the bounds are available, and no command accepts a position as input
