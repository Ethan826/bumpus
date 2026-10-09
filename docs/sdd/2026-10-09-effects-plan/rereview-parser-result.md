# Re-review: fix-parser fix round (96f5c0e..3aa1217)

### Finding Verdicts

1. **(Important) Handler arguments regressed to bare `operand`: ADDRESSED.**
   - Handler arguments are full chains again: `HandlerType.operand (defer rowed) inner` with
     `rowed _ = typeAndRow` (src/Format/Parse/Type.purs:84,90), read through
     `argument rowed parser` → `nested rowed` (src/Format/Parse/HandlerType.purs:50,123).
   - A row on the sole argument is lifted to be the handler row. A row on one of several
     arguments is rejected with "Unexpected effect row" (HandlerType.purs:61-68).
   - Probed against output/ at HEAD:
     - `Handler((Clock))` parses as `NamedRef Handler [Clock]` and checks OK.
     - `Handler(Int -> Int)` gives E_ARITY "Wrong number of type arguments for Handler",
       with the span `Handler(Int -> Int)`. At a3b54d3 this went through the same `ordinary`
       / `applicationSpan` / `build` path, and the argument span is the same, so the span
       matches base.
   - Tested at test/fx-handler-type.test.mjs:93-104.
2. **(Minor) Negative tests asserted only the code: ADDRESSED.**
   - Both E_EFFECT tests now assert the message and the span text (test:72-91).
   - The row-rejection table asserts the exact span text `with Log` (test:136).
3. **(Minor) Lambda-parameter and fail-clause rejections were untested: ADDRESSED.**
   - Both rows were added to the table (test:127-130).
   - Kept-row positives were added for the operation result, the signature result,
     `(Int) -> Int with Log` and a mid-chain row (test:114-119).
4. **(Minor) `findMap` over `take 1`: ADDRESSED.** It is now the named helper `leadingRow`,
   written as `Array.head` plus `segmentRow`, with a comment (src/Format/Parse/Type.purs:156-160).

### New Breakage in the Fix Diff

- **Important: src/Format/Parse/HandlerType.purs:61-68 (`apply` / `liftedRow` / `sole`)
  silently drops a second row.**
  - When the sole argument's chain already read a row, `sole` returns `Right (Just first)`
    and ignores `found.row`, which is the row read by HandlerType's own
    `optionalOn "with"` at :51.
  - Probed at HEAD:
    - `Handler(Clock with Log with pure)` checks OK as THandlerRef with row `Log`.
      The `with pure` is discarded.
    - `Handler(Clock with pure with Log)` keeps `pure` and discards `with Log`.
  - This is the defect class the brief forbids: "A written row must never be silently
    discarded".
  - Fix: in `sole`, when `found.row` is `Just`, return `Left (unexpectedRow <second row>)`.
    Add a test for it.
  - Practical impact is low because the syntax is nonsensical. At a3b54d3 the same input
    was also accepted, with the first row dropped, so no accepted program changes.
- Nothing else. Files are within budget: HandlerType.purs is 158 lines, Type.purs 233 and
  the test file 137. `Handler(Clock, Tick with Log)` and `Handler((Clock with Log))` are now
  E_SYNTAX "Unexpected effect row" at `with Log`. Both are written-row cases, which the
  brief allows to be rejected.

### Out-of-Scope Observations

- The kept-row positive test (test:114-119) does not cover `fn f(): Handler(Clock) with Log`.
  I probed it and it is still accepted as a signature row.
- Bootstrap snapshot and regression.mjs byte-identity are still unverified for this task.
  The report says the full verify was left to the controller.
