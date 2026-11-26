# Design

## A black hole, not a closed port

A closed port refuses immediately, so it cannot reproduce the failure. The stall needed a
host that accepts the connection and then says nothing - a filtered port, a suspended machine,
a stale session file after the app was killed. The script binds a loopback socket, accepts and
never writes, and points the server at it. If the server connects during the handshake, the
assert fails at 3s; if it defers, the reply arrives in a fifth of a second. That is a
deterministic reproduction of a defect that took a real editor to surface.

## Timing as the assertion

"No connect happened" cannot be observed directly from outside, but its consequence can: a
connect to that socket does not complete. So the assert is a duration, and the budget is set
far apart from both outcomes - measured 150ms against a 3s budget, where the failing case
takes the driver's 10s connect timeout.

## What it does not check

Error codes named in the playbook are validated by the unit test, which can import
`JigErrorCode`; the smoke script only checks tool names, because a black-box client has no
business knowing the enum. Each layer asserts what it can see, and the duplication is
deliberately avoided rather than repeated.

Tool descriptions are not re-validated here either - `tools_contract_test.dart` owns those -
so the smoke script stays about the wire and finishes in about two seconds.

## Both regressions were reintroduced

The check is only worth its runtime if it goes red. Each bug was put back on purpose and the
script failed with the right message: the ordering produced "initialize answers without
connecting … after 3010ms", and the escaping exception produced "connect failure is a tool
result … JigRpcCode.internal". Then both were restored.
