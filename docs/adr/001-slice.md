# ADR 001: a ground, first-order checked slice

Accepted 2026-10-07. Provisional language name Bumpus; workspace directory does
not define the final language name. Initial syntax uses fn with inline typed
parameters and a required result type, making a full top-level signature.

Choose Int/Bool, calls, wrapping addition, and if. This proves parsing,
resolution, source typing, elaboration, lowering, and execution with little
syntax. Parametric typing is the next extension after closed ADTs, not
implicitly inherited from PureScript. Conditions require both branches to
check even if one is unreachable at runtime.

Choose signed 32-bit Int, not Go int. PureScript's Int can range-check these
literals without precision loss; Go int32 gives platform-independent storage.
Go's integer overflow semantics support runtime wrapping. A helper avoids
Go's stricter typed constant-overflow checks. Larger integer types require
separate explicit primitives and tests, not a silent change to Int.
Source: https://go.dev/ref/spec#Integer_overflow

Choose strict evaluation and conditional branches. In this pure subset the
only ordering-sensitive event is divergence; Go orders function calls
lexically. Future effects/FFI must lower through sequenced temporaries rather
than rely on ordering of Go variable reads mixed with effectful calls.
Source: https://go.dev/ref/spec#Order_of_evaluation

The first compiler executable is Node plus PureScript-generated JS. Go is
the source language backend, not the implementation language of Stage 0.
This keeps the bootstrap starting point small and explicit.
