# Design

## Filter in the app, not in the client

The filter exists so a listing stays small before it crosses the wire: an agent narrowing to
one row should not pay for 120. Putting the key into that predicate is therefore a one-line
change in the handler rather than a new field on the element.

## Why the key and not the type

The three fields now searched are the three a caller can be expected to hold from earlier
work: the key it wrote, the label it read, the value it saw. `ownerType` is a guess about a
widget's class and the ref expires between frames, so including either would make `q` return
rows that the caller cannot act on with what it searched for.

## The empty result has to keep meaning "nothing"

Widening a filter is a small risk to the zero-result contract: an over-eager haystack would
make `count: 0` unreachable and turn "not found" into a weak signal. So the test asserts a
real miss as well, not only the two hits.
