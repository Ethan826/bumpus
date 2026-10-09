# Fix report: with row inside Handler(...) (FX001 Task 5)

Commit 5da7865 `fix: keep the with row inside Handler(...) (FX001 Task 5)`.

## Implemented
- HandlerType.operand takes a second parser `single` (one operand, does not read `with`). Handler arguments use it, so `Handler(L with R)` reaches HandlerType's own `with` handling and yields THandlerRef.
- Type.operand passes `defer single` (lazy self-reference).
- Silent drops closed (E_SYNTAX "Unexpected effect row", span = the row incl. `with`):
  - typeRef (parameter, type argument, constructor field, operation param, lambda param, handler label args) rejects any trailing row. Previously dropped.
  - typeAndRow rejects a row on the FIRST segment of an arrow chain (`f: Int with Log -> Int`), which has no arrow to attach to and was dropped.
  - Kept (meaningful): result row of a signature/operation; row on later segments (attached to the preceding arrow).
- Files: src/Format/Parse/HandlerType.purs, src/Format/Parse/Type.purs, test/fx-handler-type.test.mjs (97 lines, new, 12 tests).

## RED (before fix)
`node --test test/fx-handler-type.test.mjs` -> pass 2, fail 10 (.build/fx001-parser-fix-red.log). Failures: both THandlerRef shape tests (got NamedRef Handler [Clock], row gone), the repro (E_TYPE-style mismatch `Handler(Clock)` vs `Handler(Clock)`), Log-clause acceptance, Log-vs-pure parameter, and the 5 row-rejection tests.

## GREEN
`node --test test/fx-handler-type.test.mjs` -> 12 pass, 0 fail (.build/fx001-parser-fix-green.log). style/structure gates pass; purs-tidy check clean.
Note: two negative tests assert E_EFFECT (the checker's actual code).

## Verify (.build/fx001-parser-fix-verify.log, GOTOOLCHAIN=go1.26.4 npm run verify)
First run exposed structural-gate violations in my first draft (case on Maybe, >>=); fixed with maybe'/findMap. Second run: tests 752, pass 747, fail 5, all pre-existing, confirmed identical with my src changes stashed:
- fx-specialize: "a Grow handler at bare parameters makes one effect key"
- poly-run: "length(Nil) shares the length key at Int"; "keys are numbered in worklist discovery order"; "a polymorphic declaration never instantiated is not emitted"
- specialize.test.mjs: "specialize is the identity on monomorphic programs"
These belong to in-progress Specialize work (not touched). The 5,000-arm timing test passed this time. The controller-mentioned fx-signature and regression.mjs failures did not appear as test failures in the final log (the run stops at node test failures, so regression.mjs row may not have run); not edited.

## Self-review / concerns
- Behavior change: programs that wrote a meaningless row (`x: Int with Log`, `List(Int with Log)`, `Int with Log -> Int`) now get E_SYNTAX instead of silent acceptance; no existing test or bootstrap snapshot depended on it.
- A non-label argument such as `Handler(Int -> Int)` now fails with a different parse message than before (arrow no longer consumed by the argument); no test covered it.
- `fn t(): Handler(Clock) with Log` still parses as signature row (correct).

# Fix round 1 (review finding): Handler arguments as full types

Commit: fix: parse Handler arguments as full types (FX001 Task 5 review).

Changes
- HandlerType.operand now takes `rowed` (typeAndRow, lazily deferred) instead of the bare-operand `single`; arguments are full chains again, so `Handler((Clock))` is accepted and `Handler(Int -> Int)` reaches Resolve's E_ARITY "Wrong number of type arguments for Handler" as at a3b54d3.
- A row read by the sole argument's chain is lifted to the handler row; a row on one of several arguments is rejected with E_SYNTAX "Unexpected effect row" (span = the row).
- Type.purs: `leadingRow` named helper replaces findMap over take 1.
- Tests (test/fx-handler-type.test.mjs, 137 lines, 18 tests): added Handler((Clock)) and Handler((Clock) with Log) accepted; Handler(Int -> Int) E_ARITY with message and span `Handler(Int -> Int)`; multi-argument row rejection; kept-row positives; lambda-parameter and fail-clause rejections; negative effect tests now assert message and span. The E_ARITY span is the whole application, derived from the untouched `ordinary` path (a3b54d3 not rebuilt).

RED (before fix, .build/fx001-parser-fix2-red.log): 15 pass, 3 fail: parenthesized label, Handler(Int -> Int) (got E_SYNTAX), multi-argument row (got "Expected ')'").
GREEN: `node --test test/fx-handler-type.test.mjs` -> 18 pass, 0 fail (.build/fx001-parser-fix2-green.log). Related fx-*, fn/adt/poly-syntax, diagnostics, depth, row-*, style, structure: 308 pass, 0 fail. purs-tidy clean. Full verify not run (controller does it).

# Fix round 2: second row inside Handler(...)

Change: in HandlerType `sole`, when the lone argument's chain carried a row and a trailing `with` row is also present, the trailing (second) row is rejected via `unexpectedRow` (E_SYNTAX "Unexpected effect row", span = that row including `with`). Neither is dropped silently any more.
Tests: `Handler(Clock with Log with pure)` and `Handler(Clock with pure with Log)` assert code, message and span (`with pure` / `with Log`). RED (.build/fx001-parser-fix3-red.log): 18 pass, 2 fail. GREEN: test/fx-handler-type.test.mjs 20/20 (.build/fx001-parser-fix3-green.log).
Related: `node --test test/fx-*.test.mjs test/fn-syntax.test.mjs test/diagnostics.test.mjs test/style.test.mjs test/structure.test.mjs` -> 248 pass, 1 fail: "20,000 let items compile in linear time" (fx-block.serial), a timing test that failed under the parallel glob run and passes alone (1 pass, 1.4 s). purs-tidy clean. No full verify.
