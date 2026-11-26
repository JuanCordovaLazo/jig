# Design

## The value is the proof, so the value is the answer

`tap` proves itself by finding a live node that owns the action. A step has a better witness
available: the control reports what it holds, and Flutter reports what the next step would
make it. So `adjust` reads before, refuses when `increasedValue` equals `value` (already at
the end, before dispatching anything), applies the steps, reads after, and refuses when the
value did not move. What comes back is the value, because that is what the caller wanted.

A control that reports no value is refused rather than reported as `ok`. Attempting the step
and hoping would be the same class of defect as a tap that reports success on a covered
button.

## One code, three messages

`ADJUST_REFUSED` covers "no steps exposed", "already at that end" and "the value did not
move". They share a code because the caller's next move is the same shape - this call cannot
do what was asked - and the message says which, with the current value in `candidates`.
Adding three codes would multiply the enum for a distinction the message already carries.

## No twelfth extension

`ext.jig.tap` already means "perform an action on an element through its semantics node", and
`long` was already choosing a different action. `action=increase|decrease&times=n` is the
same shape, so the surface stays at eleven and the budget rule keeps its meaning. The CLI and
MCP still present `adjust` as its own verb, because for a caller the intent and the result
differ from a tap.

## Acting looks down; the listing does not (yet)

`Slider` carries the caller's key, and the node advertising `increase` is owned by a render
object `Slider` builds below itself. Measured in a widget test: the keyed element's render
object is a `RenderSemanticsAnnotations` with a null node, and the control's node is six
levels down. So `_liveAdjustable` searches the subtree, pre-order, depth-bounded - while
`tap` keeps its upward search, because looking down there would let a key on a row resolve
to a button inside it.

The listing still attributes keys upward only, so `find --key` disagrees with `adjust --key`
for this one shape. That gap predates this change, is written up in `docs/HANDOFF.md`, and is
left alone rather than half-fixed: making the listing search down would create the mirror
asymmetry against `tap`.
