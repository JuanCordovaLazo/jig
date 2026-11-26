# Spec Delta

## ADDED Requirements

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
reported. Bounds SHALL be informational only; no operation SHALL accept a
caller-supplied position as input.

#### Scenario: A widget carries a key

- **WHEN** a widget provides a key and appears in a listing
- **THEN** the listing reports that key so it can be used as a selector directly

#### Scenario: A widget exposes no label

- **WHEN** an interactive widget is labelled by nothing, such as an icon-only button
- **THEN** the listing still reports its owning widget type, so it remains addressable by type

#### Scenario: Bounds are read but never supplied

- **WHEN** a caller reads the bounds of an element to reason about a region of interest
- **THEN** the bounds are available, and no command accepts a position as input
