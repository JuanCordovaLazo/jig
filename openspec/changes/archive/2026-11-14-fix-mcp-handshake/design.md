# Design

## The handshake must not depend on the transport

An MCP client owns the startup deadline and the server does not. Anything the server does
before reading the first message spends that budget, and the client's timeout message -
"never became ready" - describes the symptom, not the cause: the operator sees a server that
started and a log that is empty, which reads like a protocol bug.

So the loop starts first and the app is connected on demand. `JigLazyVerbs` makes that a
property of the verbs rather than a branch in the bin, which is what let it be tested
without a socket: the ordering, the reuse, the retry after a failure, and the
`NOT_CONNECTED` answer are all plain unit tests.

## Success is cached, failure is not

A live connection is meant to be reused - reconnecting per call would be slow and would drop
the sequence-number continuity `events --since` depends on. A failed connect is the opposite:
the usual reasons are an app that is still starting, or one relaunched without restarting the
editor, and both are fixed by the next attempt. Caching the failure would make a stale
`NOT_CONNECTED` outlive the condition.

## A timeout in the driver, not in the caller

The unbounded connect was not an MCP problem; `jig ping` against a filtered port blocked for
over two minutes too. Putting the bound in `JigConnection.attach` fixes both entry points and
gives one message - `no answer within 10s` - instead of leaving each caller to invent its own.

## Nothing a handler throws may reach the loop

The `connect` tool crashed the server on its first real use: `attach` threw a
`JigConnectionException`, the tool had no catch, and the exception unwound through the stdio
`await for` and ended the process. Two layers now contain it - the tool returns
`NOT_CONNECTED`, and the dispatcher turns any remaining exception into an `isError` result -
because a client cannot recover from a server that exits mid-session, and the log it leaves
behind is a stack trace rather than a diagnosis.

## `connect` is not a verb, and that is the point

Every other tool maps to a verb and the mapping is the design. `connect` maps to nothing:
it changes which verbs the server has. That is why it takes a different code path
(`standalone`) instead of being forced into the verb shape - a tool that pretends to be a
verb would need a fake verb behind it, and the fake would be the lie.
