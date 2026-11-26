# Design

## Prose, not just types

A JSON Schema is enough for a client to validate a call and not enough for a model to
choose one. "Which of these four selectors should I use?" is answered by stability
(`key` survives a refactor, `type` breaks on one), and no type carries that. So the
descriptions say which spelling to prefer and why, and the schema keeps the same shape the
CLI accepts so one mental model covers both.

The cost is real: the payload tripled. It is paid once per session, and against it a single
avoided call - `tree`, read the key, then `tap` - is larger than the whole delta.

## The constraint that `required` cannot express

`tap` needs one of five spellings and none of them individually. `required: [...]` would
demand all of them; leaving it out lets a schema-valid call fail at the handler, which is
exactly the "rejected after the fact" pattern this change is about. `anyOf` over five
single-key `required` objects says the true thing, and it is plain JSON Schema, so any
client that reads schemas at all can read it.

## A test for the manual, not for the code

The definitions are data, so they can rot silently: adding a tool with a name and a handler
still passes every behavioural test. `tools_contract_test.dart` asserts the properties that
make the list usable - a description of more than a phrase, a documented argument, the
enums, the declared mandatory argument, the one-of arms, and that each verb names the
error it really produces. It is the same bargain as the fixture matrix: a claim about the
contract gets a check, or it is an opinion.

## One failure mode per verb, chosen from the real enum

The list is not every code a verb can emit; it is the one a caller plans around -
`ELEMENT_NOT_VISIBLE` for a covered target, `GESTURE_NO_EFFECT` for a drag that reached
nothing, `CLEAR_REFUSED` for a field that puts text back. Each is in `JigErrorCode`, so the
test cannot drift into describing an error that does not exist.
