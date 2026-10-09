# Task 7 report: Go lowering of handlers, operations and failures

Commit e9a613f `feat: Go lowering of effect handlers (FX001)` (not pushed).

## Implemented
- Mode: `usesContext` (Format.Go.Context) over the emitted IR: any effect
  layout or any of the six effect nodes. In the mode every function, stage,
  lambda, constructor, lifted match/block/pipe/apply helper and function
  type takes `ctx *waxwingCtx` first (types spell `*waxwingCtx` unnamed);
  `main` is called with `nil`. Otherwise output is unchanged (bootstrap
  snapshots and Console-only programs: no `ctx`).
- Runtime (emitted only in the mode): marker, abort, ctx list, waxwingInstall /
  Frame / Find / Fail[R] / Handle[R]. Keys: user effect = EffectId+1, Fail
  families = -1 (Int), -2 (Bool), -3 (Unit), -4-t (HeadData t) (ruling F1);
  missing handler is a plain `panic("no handler for L")` (F7).
- Effect.purs: handler struct per layout (empty for Console/Fail, F3),
  perform functions `waxwingEff{N}Op{k}` calling the clause with `frame.outer`,
  handler values (clauses lifted as `waxwingFn{f}Lambda{k}`, closure over free
  locals). Operations are Wrappers, so Perform = Call-like and OperationRef =
  function value through the existing staging (F2).
- Handle.purs: `With{k}` helper (installs on its own ctx), `Handle{k}` helper
  (fresh non-zero-size marker per family, body in waxwingHandle, clause runs
  after return in the outer context), `fail` as `waxwingFail[R](ctx,key,v)`.
- Guard (Features.Specialize.Unlowered) and its Compile call deleted; the
  Expression `unlowered` stub and wildcard arms replaced by explicit arms
  (Expression, Usage).

## Files
New: src/Format/Go/{Context,Effect,Handle}.purs, test/fx-run.test.mjs,
test/fx-run-programs.mjs. Deleted: src/Features/Specialize/Unlowered.purs.
Modified: Format/Go.purs and Go/{Apply,Block,Data,Entry,Expression,Lambda,
Lowered,Match,Pipe,Stage,Usage,Value}.purs, Program/Compile.purs,
Features/Check/{Consume,Match,Tables,Use}.purs, test/{go-batch,regression,
fx-handler-check.test,fx-specialize.test}.mjs, scripts/{regression,regression-fn}.mjs.

## Two checker defects found and fixed (outside the brief's file list)
Writing the `Job(Int, Log + Clock)` test exposed Task 4/5 bugs, both needed to
run any stored effectful function:
1. Constructor patterns built `TData owner args []`, dropping row arguments:
   `match j { Job(f) => ... }` failed with `Expected Job(Int), found Job(_)`.
   Fix: shared `ownerType` (Check/Tables) used by construction and patterns.
2. `consume` did not resolve a bound row tail, so a field row `Log + Clock`
   reached through a meta looked open and failed (`cannot be made equal`).
   Fix: resolve the row against the substitution first (Check/Consume).
Both are covered by the `jobs in a list under two handler sets` case (fails
without either fix).

## TDD
RED: `GOTOOLCHAIN=go1.26.4 node --test test/fx-run.test.mjs` before any
lowering: 19 of 21 fail with `unlowered effect` (the 2 passing are the
no-ctx text checks); saved at .build/fx001-task7-red.txt.
GREEN: same command, 22 tests (after adding one staged-values case), all pass.
Mutants in an isolated copy (src copied to scratchpad, own output dir):
clause run with the performing ctx -> cases 1-3 fail; `handle` consuming every
abort -> cases 3 and 6 fail.

## Ruling F4 (each 'unlowered effect' assertion replaced)
- fx-handler-check: handler / failure stop tests -> `runGo` with exact stdout
  ('1\n', '0\n'); handler type in signature / later field -> build and run
  ('0\n'); 20,000-arrow spine -> compile is Right and contains the empty
  `type waxwingEff0 struct {\n}` (still no recursive traversal).
- fx-specialize: guard test -> 4 programs built and run, exact stdout.
- regression 'handler-metadata' re-targeted to `effect-free-ctx` (mutant:
  ctx mode whenever there are functions; probe: Console-only Go has no `ctx`).
  Row `block-order` needle updated for the new Apply text.

## Verify / regression (GOTOOLCHAIN=go1.26.4)
`rm -rf output && npm run verify` (.build/fx001-task7-verify.log): purs-tidy,
build, strict rebuild, structure gates pass; parallel phase 782 tests, 0 fail;
serial phase 10 fail, all timing bounds as the known T007 environment failures:
fn-linear-timing 8 (value 2072ms/1200, over, lambda, mismatch, partialFirst,
partialAll, parenthesized, pipe 898ms) and fn-scale 5,000-parameter 2
(go build 19378 ms; phases 2297 ms/1650). Note 8 not 7 linear-timing: pipe is
borderline (898 vs bound ~750). With Consume.purs reverted the same 8 fail
(2223/1200, ..., pipe 764/750), so it is not caused by this change. verify
stops there; `node scripts/regression.mjs` run separately: 33 rows, exit 0
(.build/fx001-task7-regression.log).

## Self-review
- Bounds unchanged; no check disabled. Files <=250 lines (structure gate []).
- Constructors take ctx in the mode (uniform convention for CtorRef values).
- Handle body is a func literal in the lifted helper (not lifted separately).
## Concerns
- The two checker fixes widen scope beyond the brief; reviewer should check them.
- Handler clause rows must equal the surrounding row at `with` (design); tests
  pass handlers across functions with `...e` rows accordingly.
- Defer/crash/cleanup/defect report and main recovery wrapper are Task 8.

## Fix round 1 (review findings)
Changes: (1) Handle.purs `frames` folds over the reversed clauses so clause 0
is innermost (comment fixed); (2) check-level tests test/fx-check-fixes.test.mjs
(pattern on Job(Int, Log); call through Job(Int, Log + Clock) field); (3)
`installKey` (Handle.purs) emits a panicking `malformed` int expression for a
non-handler type or missing layout; Lowered.effectShape now returns Maybe
(operationWrapper keeps the existing `missing` convention).
Covering tests: fx-run cases "two clauses of one family: first is innermost"
(payload types -> 5; result -> 3).
Isolated-copy mutants (scratchpad/mut, own output): frames un-reversed ->
fx-run cases 19, 20 fail; Consume.purs at HEAD~1 -> fx-check-fixes test 2
fails; Match.purs old `TData owner args []` -> tests 1 and 2 fail.
Commands: `node --test test/fx-check-fixes.test.mjs test/fx-run.test.mjs` 26/26;
style, structure, fx-*, fn-run, compiler tests: 274 pass, 1 fail
(fx-block.serial "20,000 let items" timing bound, environment T007 class, not
related). purs-tidy and structure gates clean. No full verify (controller).
