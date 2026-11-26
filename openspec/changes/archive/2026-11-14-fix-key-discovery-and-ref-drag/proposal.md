# Proposal

## Why

A listing printed handles and keys that could not always be used. On `/form`,
`jig find --key rating_slider` answered `count: 0` while `jig adjust --key
rating_slider` moved the same slider on the same frame, and on `/refresh` a keyless
scrollable emitted a ref whose node no widget owned, so `jig swipe --ref n178`
answered `ELEMENT_NOT_FOUND: No widget owns n178 in the current frame`. Both were
found by a black-box agent that had read the listing and trusted it.

The cause is one rule applied in one direction: the listing attributed a key by
walking up from each element's render object. A `Slider`'s actioned node is below the
widget that carries the key, and a `ListView`'s scroll node is above the viewport its
first render object resolves to, so the walk either found an ancestor's node or
found nothing. Acting did not share the mistake, which is why the two disagreed.

## What Changes

- A key is reported on the node that can act for its widget: the search runs over the
  widget's own subtree, and when the node it reaches cannot act but another node
  covers an identical rectangle and can, the key moves there.
- Keys the framework gives itself (`ValueKey(_ScaffoldSlot.appBar)`) are not reported.
- Every handle a listing prints is usable: a gesture resolves a ref whose node no
  widget owns by matching the node's rectangle against painted boxes, so `swipe
  --ref` works on a keyless scrollable.
- The rectangle comparison accounts for the semantics tree reporting physical pixels
  while a render box reports logical ones.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent-harness`: the requirement "Element listings carry the selectors a caller can
  use" gains the rule that a reported key belongs to the node that acts, and that a
  reported handle is one a gesture can use.

## Impact

- `packages/jig_flutter/lib/src/element_index.dart`: key attribution, the subtree
  search, rectangle lookup, and the listing filter that hid keyed but actionless
  nodes.
- `packages/jig_flutter/lib/src/actions.dart`: ref resolution for `tap` and `swipe`.
- `apps/fixture/test/adjust_contract_test.dart`,
  `apps/fixture/test/swipe_contract_test.dart`: the two regressions.
- `docs/CONTRACT.md`, `docs/HANDOFF.md`, `docs/fixture-matrix.md`, `README.md`.
