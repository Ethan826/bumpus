# Task 9 report: diagnostic quality (FX001)

## Implemented
- Occurrence links in Subst (first wins, merged by compose), recorded by every
  row unification: unifyRows, consumeVia and settleRows (postponed pairs keep
  their Sides). Origins (first per occurrence) live in checker State.
- New modules: Provenance (Consumed/Boundary/Origin, trail), Origin (RowEvent
  hooks: linked, attributed), Report/Reject/Argument/DeferNotes/Path (notes,
  cross-function path by re-checking callees), Format.Diagnostic.{Row,Note,Name}.
- consumeAt takes a Consumed; consumeVia adds boundary (Installation, DeferItem)
  and deferred-occurrence links. Sites (CheckEnv.sites) make installed labels
  distinct occurrences. Failure gained occurrences and RowPayload (non-Fail
  labels, traced unifications only, so Task 3 unify-row tests are unchanged).
- Messages: Expected State(Bool), found State(Int) with elision; side condition
  names ...r (callee variable) and abbreviates rows (visibleLabels 4, pathHops 2,
  maxNotes 4, maxCharacters 2000). Wire related = [{span, message}].
- Entry (main) uses provenance; primary span is the consuming call.

## Files
src/Features/Check/{Occurrence,Subst,Binding,UnifyRow(243 lines),Unify,RowSide,
Scheme,Context,Infer,Consume,Use,Call,Apply,Operation,Failure,Handler,Lambda,
Defer,Entry,Require,RowName}.purs, Check.purs, new modules above, Domain.Problem,
Domain.Syntax, Format.Diagnostic(.Name/.Note/.Row), Format.Wire,
scripts/regression.mjs (deferred-fail-effect needle renamed to the renamed line),
test/fx-diagnostics.test.mjs, fx-diagnostic-origins.test.mjs,
fx-diagnostics-support.mjs, fx-signature.test.mjs (related now asserts notes).

## TDD
RED: .build/fx001-task9-red-import.log (module absent). GREEN: 21 new tests pass.

## Verify / regression
- Parallel phase: 839 tests, 838 pass; the one failure is large-source
  "three-thousand-constructor match" (5.0-6.4 s vs 5 s bound), the T004 flake
  allowed by R1; same code at base measured 3.5-4.2 s vs mine 3.5-4.0 s, passes
  alone. verify therefore stops there.
- Serial phase run explicitly: 13 failures, identical set and similar timings
  at the base commit (fn-linear-timing 8, fn-scale 5 incl. 1,000-arrow, fx-block
  20,000 lets, match ladder).
- node scripts/regression.mjs: exit 0. purs-tidy, structure gate, strict rebuild OK.

## Existing diagnostics unchanged
Notes are only rendered for effect/label problems (Format.Diagnostic.noted), so
non-effect diagnostics have related: [] by construction (test asserts 9 kinds);
all pre-FX001 tests pass unedited. Only fx-signature (FX001) updated for notes.

## Concerns
- Boundary spans: Resolved carries no signature/annotation spans, so notes use
  the whole declaration, or the parameter NAME for "this parameter must be pure"
  and named rows. Precise `with` spans need Resolve to carry them.
- maxNotes bounds non-path notes; path lines are bounded by pathHops separately.
- Cross-function path re-checks callees at report time (failure path only).
- Matched links are recorded both ways (entry names first matching label) to
  recover which callee label an origin consumed.
- DeferMayPerform application note searches Apply nodes only; falls back to the
  deferred expression span for calls.
- "Mutants" proof rows left to Task 12.

## Fix round 1 (review-task9-result.md)
- I1: Resolved.FunctionDecl.rowSpan and Parameter.rowSpan (Syntax RowRef spans,
  carried by Resolve; operation parameters Nothing); CheckEnv.rowSpan. Boundary
  notes now point at the written `with` row / the parameter's `with` annotation.
  Choice for `with Log` (labels + ambient tail): "the signature of f does not
  allow L" at the `with`; "has an ambient row" only when no `with` is written
  (then at the declaration). Tests: with Log, with pure, with ...e, pure param.
- I2: Format.Diagnostic.Row.shortLabel (maxLabelCharacters 120): a longer label
  prints as Effect(…) in headlines, rows and notes, so the whole diagnostic
  stays within maxCharacters; effect and shared tail remain named. Gap: this is
  string-level, not E011-style structural elision. Two tests (headline, conflict).
- I3: a Fail key settled after the defer now notes the application inside the
  deferred expression ("Fail(E) comes from this function value" at f(y)).
- M1: DeferMayPerform fallback for a named call: "... comes from this call of f".
- M2: comment on the structural related:[] guarantee.
- Verify: parallel 842/843, only the large-source T004 flake (passes alone);
  serial 12 failures, a subset of the base T007 set; regression exit 0;
  tidy/structure gates clean.

## Fix round 2 (rereview-task9-result.md)
- N1: boundary spans use the written `with` only when the concerned row is the
  parameter's own arrow (pure top-level row for "must be pure"; top-level tail
  for "...e is declared here"); a nested row falls back to the parameter name.
  Callee parameters keep both spans. Tests: nested pure row, nested row variable
  (both seen failing on the previous build).
- N2: the late-Fail-key note no longer scans for any application holding a
  Fail. It follows the provenance of the reported label to the `fail` that
  raised it, then picks the first application in the deferred expression whose
  callee is a local let-bound to a function containing that `fail`
  (settleDeferred now receives the function body); none found means no note.
  Tests: `defer { k(()); a(A) }` blames a(A); `defer { b(B); a(A) }` blames the
  call of the reported family. (A tail-claim approach attributed the shared
  lambda row to the first consumer and was dropped.)
- I2 comment in Format/Diagnostic/Row.purs corrected: maxCharacters hard-bounds
  notes; headlines grow with long leaf type/effect names (E011 gap, for BACKLOG).
- Verify: parallel 846/847 (large-source T004 flake, passes alone); serial 13
  timing failures, same T007-style set as base (one 1,000-arrow/partial-chain
  test differs by timing noise); regression exit 0; tidy/structure/strict clean.

## Fix round 3
- N1 residual: topRowPure now requires the parameter's top arrow to be its only
  pure row (counted through the spine and nested types); otherwise the note
  names the parameter. New test `f: Int -> (Int -> Int with pure) with pure`
  seen failing first.
- N2 test tightened: `defer { b(B); a(A) }` asserts Fail(B), the note at b(B)
  and the raise at b's fail(x, by exact span.
- Verify: parallel 847/848 (large-source flake, passes alone 15/15); serial 13
  T007-style timing failures as before; regression exit 0; gates clean.
