# agent-harness Specification

## Purpose
TBD - created by archiving change bootstrap-agent-harness. Update Purpose after archive.

## Requirements

### Requirement: Elements are addressed, not pointed at

The system SHALL address an element by key, accessibility label, widget type or
text, and SHALL NOT accept a caller-supplied screen coordinate as a selector.

#### Scenario: Selector resolves to exactly one node

- **WHEN** a caller taps by accessibility label and exactly one node matches
- **THEN** the action is performed through `SemanticsOwner` and the response
  reports the node ref and label

#### Scenario: Selector is ambiguous

- **WHEN** more than one node matches the label
- **THEN** the command fails with `ELEMENT_AMBIGUOUS`, lists candidate labels, and
  performs no action

#### Scenario: Target is behind a modal

- **WHEN** a dialog or bottom sheet is on top and the caller targets the covered
  element
- **THEN** the command fails with `ELEMENT_NOT_FOUND` rather than tapping through

### Requirement: Positions are derived at the instant of the action

The system SHALL compute any screen position from the widget's render box at the
moment of the action and SHALL NOT cache positions between commands.

#### Scenario: Target moves between discovery and action

- **WHEN** the list containing the target reorders continuously
- **THEN** the action still reaches the intended widget

### Requirement: State is readable without source evaluation

The system SHALL expose named state readers registered by the app and SHALL return
a snapshot of all of them in a single call.

#### Scenario: One reader throws

- **WHEN** a registered reader raises
- **THEN** the snapshot reports that entry's error and still returns the others

### Requirement: Failures are actionable

Every failure SHALL carry a stable wire error code, and SHALL include candidate
matches and a next command whenever those exist.

#### Scenario: Element is not found

- **WHEN** no node matches the selector
- **THEN** the response includes the closest labels observed and a hint command

### Requirement: Internal activity is observable after the fact

The system SHALL record HTTP exchanges, log lines, navigation transitions and
unhandled errors in a bounded buffer with a monotonic sequence, and SHALL let a
caller read events after a given sequence.

#### Scenario: Chaining an action to its consequences

- **WHEN** a caller performs an action and then reads events after the action's
  sequence number
- **THEN** only events caused by that action are returned

#### Scenario: Transport failure reaches no response modifier

- **WHEN** a request times out
- **THEN** an `http` error event is recorded with the elapsed time

### Requirement: The app's existing behaviour is preserved

Installing the runtime SHALL NOT replace the Flutter binding, SHALL NOT insert an
overlay, and SHALL chain rather than replace `FlutterError.onError`.

#### Scenario: App already reports crashes

- **WHEN** the app installed a crash reporter before `runApp`
- **THEN** that reporter still receives every error after jig is installed

### Requirement: The runtime does not choose an architecture

The app-side package SHALL NOT depend on any state management library.

#### Scenario: Non-GetX app adopts jig

- **WHEN** an app without GetX installs the runtime
- **THEN** it resolves without pulling `get` as a dependency

### Requirement: Back navigation follows the app's own policy

The system SHALL expose a back operation routed through the same mechanism as the
platform back button, so app-level interception is honoured rather than bypassed.
The operation SHALL report whether a route was popped, and SHALL fail with a typed
error when the app declines.

#### Scenario: Popping a pushed route

- **WHEN** a caller invokes back while a route is pushed on top of another
- **THEN** the route is removed and the operation reports that a pop occurred

#### Scenario: The app refuses the pop

- **WHEN** the app intercepts the back request and decides not to pop
- **THEN** the operation reports a typed refusal and does not claim success

#### Scenario: A modal is stacked over the route

- **WHEN** a dialog or bottom sheet is open and a caller invokes back
- **THEN** the topmost modal is dismissed and the route underneath is unchanged

### Requirement: Elements beyond the viewport are reachable without pixel arithmetic

The system SHALL make a non-rendered element reachable by paging its containing
scrollable with that scrollable's own accessibility scroll action, driven from
inside the application's UI loop. Paging SHALL be bounded and SHALL report
exhaustion with the elements actually rendered.

#### Scenario: The target is in a long list and not built

- **WHEN** a caller targets an element of a lazily built list that is far from the viewport
- **THEN** the operation pages until the element appears and returns a handle to it

#### Scenario: The target never appears

- **WHEN** the step budget is exhausted without finding the target
- **THEN** the operation fails with a typed exhaustion error that lists what is rendered

#### Scenario: Two scrollables are nested

- **WHEN** the target sits inside a scrollable nested in another scrollable
- **THEN** the caller can name the one to page, and without that name the operation does not silently pick one

#### Scenario: The scrollable is horizontal

- **WHEN** the containing scrollable pages horizontally
- **THEN** paging moves along that axis

#### Scenario: The target is behind a modal

- **WHEN** the target exists in the widget tree but is covered by a modal
- **THEN** no paging occurs and the same typed failure is reported as for acting on a covered target

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
