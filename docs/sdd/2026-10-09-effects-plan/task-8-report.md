# Task 8 report: `defer`, `crash`, cleanup policy and defect report

Status: DONE_WITH_CONCERNS. Commit 041cb31 `feat: defer, crash and cleanup (FX001)`
(not pushed; docs/ untouched; trailers follow the session attribution reminder,
`Claude Sonnet 5.5`, not the `Opus 5.5` of the context file).

## Implemented
- Syntax/parse: `defer e` block item (`Syntax.Item.Defer`); last item without `;`
  is E_SYNTAX `Expected ;` (as `let`). Resolve: `Resolved.Item.Defer`, builtin
  global `crash` (`BuiltinCrash`, `CrashRef`, `Crash`) resolved like `print`.
- Check: `crash(v)` (arity 1, E_ARITY otherwise; result a fresh type, no effect;
  printable argument judged by `Check.Printable` with its `Expected a printable
  value, found <t>` text; bare `crash` is a monomorphic lambda like `printRef`).
  `defer`: new `Features.Check.Defer`. `e` is checked against a fresh open row
  meta, must be Unit, then any Fail label with a settled key in that row is
  E_EFFECT `defer must not fail, but it performs <L>` (new `DeferMayFail`
  problem) before the row is consumed into the current row. A Fail whose key is
  not settled (unification postpones that pair, so it is not in the row) is noted
  in `State.deferrals`; `rejectDeferred` judges them after `settleKeys` so the
  message names the settled payload.
- Specialize: `Crash`/`Defer` copied; `IR.TypeInfo` gained `arguments` (the key's
  type arguments) so the report can name a payload type.
- Go: `Format.Go.Block` (blocks with `defer` register closures in
  `waxwingCleanups` and `defer waxwingCleanup(&waxwingCleanups)`; blocks without
  emit neither), `Format.Go.Report` (`crash` lowering, payload description,
  `<not printable>` decided statically from the type), `Format.Go.Cleanup`
  (runtime text, `usesDefects`, main guard). `waxwingFail` takes a report
  function: `nil` unless the program has `defer`/`crash`. Imports are
  `fmt` and/or `os` as needed; programs without defer/crash are unchanged.
  main = `func main() { defer waxwingReport(); ... }` only for such programs.
- Report: first cause as is, each later one prefixed `cleanup failed: `, `\n`
  escaped, stderr, exit 1. Causes: `crash: V`, `fail(T): V`, `no handler for L`
  (F7), other Go panics `panic: ...`.

## Files changed
src/Domain/{Syntax,Resolved,Problem,Checked/Internal,IR/Internal}.purs;
src/Features/Check/{Defer (new),Block,Operation,Infer,Scheme,Printable,
Comparable,Coverage,Failure,Instantiation,Walk,Entry}.purs, src/Features/Check.purs;
src/Features/Resolve{,/Block,/Expression}.purs;
src/Features/Specialize/{Body,Keys,Seeds}.purs;
src/Format/{Diagnostic,Go}.purs, src/Format/Parse/Block.purs,
src/Format/Go/{Cleanup (new),Report (new),Block,Context,Expression,Handle,Lowered,Usage}.purs;
test/fx-cleanup.test.mjs (new), test/go-batch.mjs (main-shape guard accepts the
`defer waxwingReport(); ` prefix), test/specialize.test.mjs (expects the new
`arguments: []` on monomorphic IR types).
Deviation from the brief's list (F19): runtime text is in the new
`Format.Go.Cleanup`, not `Context.purs` (250-line cap); `Context.purs` only
gained `children` export, the `report` field of `waxwingAbort`, and the
`waxwingFail` parameter.

## TDD evidence
RED (HEAD in an isolated copy, new test file only): `node --test test/fx-cleanup.test.mjs`
-> 26 tests, 2 pass, 24 fail (the 2 passing are the "emits no cleanup/defect
runtime" negatives, trivially true at HEAD). Failures are
`Expected an expression` at `defer` / `crash(...)` etc. (log:
.build/fx001-task8-red.log; the 26th test, the retroactive-Fail rejection, was
later dropped, see concerns, leaving 25).
GREEN: `GOTOOLCHAIN=go1.26.4 node --test test/fx-cleanup.test.mjs` -> tests 25,
pass 25, fail 0 (.build/fx001-task8-green.log).
Isolated mutants (scratch copy) each caught: cleanup drops the pending cause
(4 fail), FIFO cleanup (3), defer evaluated at registration (10), defer check
removed (3 rejections), Go defer always emitted (1), deferred-key pass removed
(1), crash argument not judged printable (1).

## Verify / regression
`rm -rf output && GOTOOLCHAIN=go1.26.4 npm run verify` (.build/fx001-task8-verify.log):
format, build, strict rebuild, structural gates pass; parallel phase 811 tests,
811 pass; serial phase 22 tests, 13 pass, 9 fail, all the known timing set
(fn-linear-timing 7 of 8 up to 8, fn-scale 5,000-parameter 2; e.g. `took 2273 ms,
bound 1200`, `go build took 17448, bound 10000`). fn-linear-timing is identical at
HEAD (8/8 fail there, same times). fx-block.serial passed. Verify stops before
regression, so `GOTOOLCHAIN=go1.26.4 node scripts/regression.mjs` was run
separately: exit 0, every proof "fixed compiler passes; restored defect fails"
(.build/fx001-task8-regression.log). Bounds untouched.

## Span of the defer diagnostic
The whole item: `defer` keyword start through the last token of its expression
(closing parenthesis included), e.g. `defer fail(E)`, `defer risky()`. Built with
`spanned` in `Format.Parse.Block.deferItem`, not `exprSpan`, because the existing
`fail(e)` expression span stops before `)` (Task 5 quirk, untouched).

## Self-review findings
- Fixed during work: strict `where` made `payloadName` recurse forever; over-long
  comment line caught by structural gate; `specialize` identity test needed the
  new field.
- `crash` bare-reference form and wrong arity covered; `defer` last-item syntax covered.
- A Go runtime panic as the pending cause reports `panic: <text>` (not specified;
  chosen so nothing is dropped).

## Concerns
1. `defer must not fail` is not complete for two shapes the type system cannot
   separate from the current row (unification identifies the deferred row's tail
   with the current row after consumption): (a) a Fail made visible later through
   a shared meta (`let f = fn(x) => (); defer f(1); ... run(f)` with a Fail row);
   (b) a Fail through an effect-row variable (`defer g(())` with `g: ... with
   ...e`, instantiated with Fail by the caller), and a closure created earlier
   whose Fail key was still unsettled. Runtime stays safe: such a cleanup's abort
   is caught by `waxwingRun` and becomes a cleanup cause line (`fail(T): V`),
   never a lost error. I dropped my retroactive-detection test for (a); the gap
   needs a design decision (spec §2 text is satisfied only for Fail labels in the
   expression's own row). Suggest a BACKLOG/ADR item.
2. A deferred-key Fail inside a `handle` that does handle it, within a defer, is
   rejected (false positive; needs the payload unresolved when the `handle` is
   checked, so very rare).
3. `Format.Go.Report.payloadName` recurses per type argument (a 5,000-deep
   nested payload type could overflow the JS stack; spines of arrows also).
4. Two-crashing-defers-on-normal-exit convention: the first cleanup cause is the
   unprefixed first line (spec: first line is the original cause).
5. Context file says do not edit docs/: progress/findings/BACKLOG not updated here.

## Fix round 1 (review-task8-result.md)
Changes: `Features.Check.Defer` rewritten. `defer e` is checked against its own
row meta; its resolved labels are consumed (fresh tail) into the enclosing
row, its tail is never unified with it; known Fail labels still fail eagerly.
`State.deferrals` now holds `{span, row, current}`. `settleDeferred` (called
in `Check.checkFunction` after `settleKeys`, then `settleKeys` again):
rejects any Fail (`defer must not fail, but it performs <L>`) or a rigid tail
(new `DeferMayPerform`: `defer must not fail, but it may perform any effect of
<r>`, `...` ambient / `...e` named), closes an unsolved tail, and consumes labels
that arrived later into the row the defer was checked in. The postponed-pair
scan is gone (false positive fixed). `Report.payloadName` walks arrow spines
via `IR.spine` + `foldr`.
Tests (test/fx-cleanup.test.mjs, 32 total): P1, P2, P3, P4, P5d rejected with exact
text/span (span = the defer item); false positive accepted; 5,000-arrow payload.
RED against 041cb31 src: 7 of the new tests fail, 25 pass (.build/fx001-task8-fix-red.log).
GREEN: fx-cleanup + style + structure: 46 pass, 0 fail.
Verify (.build/fx001-task8-verify.log): parallel phase 818/818 pass; serial 22 tests,
12 pass, 10 fail, all the known timing set (fn-linear-timing 8, fn-scale 5,000-parameter 2).
Regression (container restarted mid-run, rerun): exit 0, 33 proofs all
"restored defect fails". Commit trailers follow the context file (Opus 5.5).
Note: `defer handle release(()) {...}` on a callback with a rigid row is also rejected
(rigid tail rule, as ruled). A closure whose Fail arrives after the defer is
caught because the defer's tail is separate from the enclosing row.
