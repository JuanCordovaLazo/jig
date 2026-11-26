# Design

## Cost ordering, because the tools are not equal

The four tiers are the real cost structure of the harness, not a preference: a registered
reader is a value lookup, a tree listing walks the semantics tree, an action waits for
frames, and a screenshot rasterises and encodes a full frame that then has to be read by
something. Saying "cheapest first" turns thirteen peers into a decision a model can make
before spending anything.

## Saying what `screenshot` is not for

"Why not just look at it?" is the wrong instinct to leave uncorrected, because it is
plausible: a human would look. The playbook answers it in the terms that matter to an
agent - an image says nothing about what is actionable, and nothing in it can be asserted
on, so it cannot become a check. It stays available for the questions only pixels answer.

## Names that are checked, not prose that is trusted

The playbook talks about tools and error codes, which is exactly the kind of text that rots
- a renamed verb leaves an instruction to call something that no longer exists, and the
model finds out by failing. So the test extracts backticked names and requires each to be a
served tool or a defined `JigErrorCode`. Backticking is what makes the check precise: an
earlier version matched plain words and flagged the English "find out" as a call to a
`find` tool.
