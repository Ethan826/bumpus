# Review: fix-parser (a3b54d3..5da7865), `with` row inside `Handler(...)`

### Spec Compliance
- ✅ `Handler(L with R)` parses to `THandlerRef` with its row in parameters,
  results and operation types (src/Format/Parse/HandlerType.purs:39-50,
  src/Format/Parse/Type.purs:80). Probed at HEAD, and covered by
  test/fx-handler-type.test.mjs:38-51.
- ✅ Bare `Handler(L)` is unchanged: it is still a `NamedRef "Handler"` (test :53).
- ✅ The brief's repro now CHECKs OK (test :58-61). The Log and pure positive
  and negative cases are covered (tests :63-80).
- ✅ The rows the spec gives meaning to are still kept. I probed each one at HEAD:
  - the signature result row: `fn f(x: Int): Int with Log` and
    `fn f(): (Int) with Log`
  - the operation result row: `fn op(): Int with Log`
  - `(Int) -> Int with Log` and `(Int, Int) -> Int with Log`
  - `(Int -> Int with Log) -> Int`
  - a row on a middle segment: `Int -> Int with Log -> Int`
  - a lambda parameter typed `Int -> Int with Log`
  - `fn f(): Handler(Clock) with Log`

  All of them parse and resolve. They fail only with E_ENTRY because the probes
  had no main.
- ✅ The new E_SYNTAX "Unexpected effect row" fires only where the spec gives the
  row no meaning. The span starts at `with` and ends after the row, which I
  checked at offsets 77..85. Those places are:
  - a lone non-arrow type in a parameter, type argument, constructor field,
    operation parameter, lambda parameter or `fail(e: T)` clause (all through
    `typeRef`, Type.purs:63-67)
  - the first segment of an arrow chain (Type.purs:153-155)
  - `(Int with Log)`
  - `Handler(Clock) with Log` used as a parameter

  §1 attaches `with` to the nearest arrow to its left, and none of these has
  one. Before this change, programs with a row in these places were accepted
  and the row was silently dropped. The brief explicitly allows rejecting them.
- ❌ HandlerType.purs:39-43 / Type.purs:80,86 (`single _ = operand inner`):
  - Handler arguments are now read by the bare `operand` production. That
    production has no `(` group and no `->` chain.
  - **A previously accepted program is now rejected:**
    `fn f(h: Handler((Clock))): Int` used to parse. At a3b54d3 the argument went
    through `nested typeRef` → parenthesized segment → `NamedRef Clock`, and
    Resolve accepted it. HEAD rejects it with E_SYNTAX "Expected a type" at the
    inner `(`.
  - The spec gives parentheses meaning ("parentheses delimit it"; the chain
    comment says "a lone type keeps its own span, parenthesized or not"), and
    `List((Int))` is still accepted.
  - **A previously rejected program now gets a different diagnostic:**
    `Handler(Int -> Int)` was E_ARITY "Wrong number of type arguments for
    Handler" (from Resolve/HandlerType.purs:26). It is now E_SYNTAX
    "Expected ')'" at `->`.
  - Both break the global constraints. The base behaviour comes from reading
    the a3b54d3 source. HEAD behaviour was probed against output/.
- ⚠️ The bootstrap/*.go snapshots being byte-identical is not shown. The report
  says the verify run stopped at 5 pre-existing node test failures, so the
  snapshot and regression.mjs stages may not have run. No regression.mjs or
  regression-fn.mjs row targets Type.purs or HandlerType.purs, so the risk is
  low, but it is unverified.

### Strengths
- The root cause is diagnosed correctly: `segment` consumed the `with`, and
  `typeRef` threw it away.
- The fix also closes the related silent drops instead of patching only the
  Handler case.
- The diagnostic is a single shared helper (`unexpectedRow`) with an exact
  span.
- The comment on `combined` explains why only the first segment can lose its
  row. That matches `folded`, where each row annotates the arrow before it.
- TDD evidence is recorded: red 2/10, then green 12/12. I re-ran the new file
  plus fx-handler-check, fx-signature, fn-syntax and diagnostics: 111 pass,
  0 fail.
- The files stay within budget: Type.purs is 230 lines, HandlerType.purs 133,
  and the test file 97.

### Issues

**Critical:** none.

**Important**

1. **HandlerType.purs:39-43, Type.purs:80,86: Handler arguments lost the
   parenthesized and arrow forms.**
   - **What:** `Handler((Clock))` was accepted at base and is now rejected.
     `Handler(Int -> Int)` changed from E_ARITY to E_SYNTAX "Expected ')'".
     The report mentions the second one but leaves it unfixed and untested.
   - **Why:** this breaks two global constraints. A previously accepted
     program is now rejected even though the spec gives the syntax a meaning,
     and the text and span of an existing diagnostic changed.
   - **Fix:** keep parsing Handler arguments with the full chain parser,
     `typeAndRow`, and do not swap in `operand`. When there is exactly one
     argument and its chain returned a lone-type row (`init` empty, row
     present), lift that row to be the handler's row. Reject a row on a
     non-sole argument with "Unexpected effect row".
     - With that change, `Handler((Clock))`, `Handler((Clock) with Log)` and
       `Handler(Int -> Int)` behave as at base, except that the row is no
       longer dropped. The `single` parameter can then go away.
     - Add tests for `Handler((Clock))` (accepted) and `Handler(Int -> Int)`
       (E_ARITY with its base span).

**Minor**

1. **test/fx-handler-type.test.mjs:70-80: negative effect tests check only the
   code.** They assert E_EFFECT but not the message or span. Asserting the
   span would keep the tests from passing on an unrelated E_EFFECT elsewhere.
2. **test/fx-handler-type.test.mjs:82-97: two positions have no rejection
   test.** The lambda parameter (`fn(x: Int with Log) => x`) and the
   `fail(e: T with R)` clause also changed behaviour, but the table does not
   cover them. Add both rows, plus a positive row for the operation result row
   and for `(Int) -> Int with Log` to pin the kept cases.
3. **Type.purs:155: `Array.findMap segmentRow (Array.take 1 chain.init)`
   obscures intent.** It reads as "search a list" when it means "the head's
   row". Use `Array.head chain.init` with a named helper, or `bind` (the
   report says `>>=` was refused by the gate), with a comment.
4. **The verify log ends on failing tests.** The run reported 5 failures
   (fx-specialize, poly-run ×3, specialize). They are claimed to be
   pre-existing and from other work, but because they stop the run before the
   snapshot and regression stages, this task's gate is incomplete. Re-run
   those stages separately, or record that they were skipped.

### Assessment
**Task quality: Needs fixes.** The core defect is fixed correctly and the new
rejections are sound under §1. However, swapping Handler arguments to bare
`operand` regresses `Handler((Clock))` from accepted to rejected and changes
the `Handler(Int -> Int)` diagnostic, which breaks the task's hard constraints.
