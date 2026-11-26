# Design

## Two rules, and why they do not contradict `tap`

The listing and the acting verbs were answering different questions and nobody had
written that down.

- Listing asks *which name reaches this node*.
- Acting asks *which node does this name's gesture belong to*.

`tap` searches upwards only, deliberately: searching down would let a key on a row
resolve to a button inside it, so a caller would tap something it did not name. The
listing needs the opposite freedom, because a keyed widget frequently builds the node
that acts rather than owning it. Writing both down as one rule is what produced the
defect; they are separate rules with separate justifications.

## Which node a key reaches

1. Search the keyed widget's own subtree, over `RenderObjectElement`s, in pre-order,
   and take the first node found. Pre-order means the widget's own node wins when it
   has one, and its nearest descendant's when it does not.
2. If that node carries no action, and another node covers an identical rectangle and
   does, report the key there. A name that cannot act is not a selector.

`element.renderObject` cannot be the starting point of step 1: for a composed widget
it returns the *first descendant* render object, and a `ListView`'s scroll node is
owned by a gesture handler above the viewport that walk descends into. Walking the
element subtree and reading each `RenderObjectElement`'s own render object is what
finds it. Measured on `/nested-scroll`, the inner list's node is a boundary with no
actions and the scroll actions live on a sibling node covering the same box; the
promotion in step 2 is what makes `--key inner_list` a scroll target.

Keys the framework gives itself are dropped. `ValueKey(_ScaffoldSlot.appBar)` is a
`ValueKey` whose value is a private enum member, so the filter is "the string form
starts with an underscore", not "the widget is private".

The listing also stops hiding a node that a key names merely because it has no
actions, since a caller that read the key from its own source is entitled to select
with it.

## Why a gesture falls back to a rectangle

A keyless scrollable's actioned node is owned by a render object below every element
that names it, so `elementForNode` finds nothing and `ELEMENT_NOT_FOUND` was the
honest answer to a handle the listing had just printed. A drag needs a box, not an
owner: `swipe` resolves the node's own rectangle and looks for the deepest painted
box occupying it.

The units differ and this is the trap. `SemanticsNode.rect` is in **physical**
pixels; a `RenderBox` reports **logical** ones. Comparing them directly matched
nothing on a device at `devicePixelRatio` 3, and a drag measured against the wrong
unit would have travelled three times too far rather than failing loudly, so the
comparison scales by `devicePixelRatio` explicitly.

## Verification

In-process tests cover both regressions. On a 2560x1440 device: `find --key
rating_slider` reports one node with `increase`/`decrease`, `find --key refresh_list`
reports the list with `scrollUp`, `swipe --ref n35 --direction up` on a keyless list
succeeds at distance 576, and `refresh.count` goes 0 to 1.
