## ADDED Requirements

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
