# Design

## Context

See proposal.md. Acting already resolves a selector to a live semantics node and
lets the framework dispatch a semantics action. A drag has no such action, so this
is the first verb that emits pointer events. The rules it must not break are "no
caller-supplied coordinates" and "a gesture that cannot be proven to have reached
its target is not a success".

## Decisions

1. **Pointer events go through `WidgetsBinding.instance.handlePointerEvent`.** The
   origin is computed from the target's own `RenderBox` at the instant of the
   action, exactly as `tap` computes its position, so the caller still supplies no
   coordinate. Only a *named direction* is accepted. A delta flag was rejected: it
   hands the caller the arithmetic that the coordinate ban exists to remove.

2. **The distance comes from the element.** `swipe` moves a fixed fraction of the
   element's own width or height, so the gesture scales with the control instead of
   with a number someone guessed. There is no tuning knob in the first version; if
   a real control needs a longer path, that is evidence for a flag, not for one now.

3. **Two proofs, and both must hold.** Before dispatching, the origin is
   hit-tested and the target's own render object (or something inside it) must be in
   the hit path; otherwise the element is covered and the verb fails
   `ELEMENT_NOT_VISIBLE` before emitting anything. After dispatching, the app must
   have changed: the set of rendered identities, or the registered state readers,
   must differ from the snapshot taken before. No change means
   `GESTURE_NO_EFFECT`.

   The second proof is the load-bearing one. We cannot observe where the finger
   went, so we refuse to report a gesture that produced nothing. This is the same
   rule as `tap`, expressed for a surface that cannot confirm receipt.

4. **A new wire code rather than `internal`.** `GESTURE_NO_EFFECT` names the
   failure. Reusing `INTERNAL` would collapse "the gesture did nothing" into "the
   harness broke", which is the conflation that hid the original defects. Adding an
   enum value is additive, so the protocol stays minor-version compatible.

5. **No eleventh extension.** `ext.jig.tap` gains `gesture=swipe` plus `direction`.
   The verb composes at the extension layer rather than adding surface to it. The
   cost is a slightly overloaded name, which the contract documents; renaming the
   extension would break every existing caller for cosmetics.

6. **Row 21 only.** `slidable_delete` is absent before the drag and present after,
   so its proof needs no fixture change at all. Row 20's `onRefresh` produces no
   observable state, so covering it means editing the fixture; that is a separate
   step with its own argument.
