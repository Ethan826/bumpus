# FX009 review: c445bac (fx009, base 531e438)

Verdict: **Needs fixes** (no Critical; two Important).

## What I ran vs read

Ran, in the fx009 worktree: `npm run build`; `node --test
test/fx-fail-pairs.test.mjs` (3/3 pass); `node scripts/regression.mjs
postponed-fail nested-fail` (both proofs hold); `npm run verify`
(exit 0, 937/937 parallel, 29/29 serial, 34 regression proofs).
Ran in scratch copies (not the repo): a build of base 531e438's
Failure.purs (`base`); the new test file against base (2 fail, positive
case passes, so the new tests were seen failing); the nested-fail mutant
(`mut`); and a variant of the fix that skips the postponed check in the
first `settleKeys` call (`fix2`). I checked the probe programs below with
parse, resolve, check and wire against each build. Read: Failure.purs,
Check.purs `checkFunction`, Defer.purs, Consume.purs, Unify `settleRows`,
Subst `RowPair`/`compose`, spec §2 "Label keys" and §6, and 9a6befd's
nested-fail row.

## Important

**I1. The first `settleKeys` call now rejects pairs that `settleDeferred`
would settle.** `checkFunction` runs `settleKeys`, then `settleDeferred`,
then `settleKeys` again. The new check runs in both calls, so a pair whose
payload meta is bound only when `settleDeferred` consumes labels that
reached a deferred row late is rejected before it gets that chance. Spec
§2 says the key is "decided after the body's other constraints are
solved". Program (base: accepted and `run` prints 0; fix: E_TYPE at
`fail(E`; fix2: accepted):

    type E = E; effect Cell(a) { fn put(x: a): Unit; };
    fn hole(u: Unit): a = hole(u);
    fn call(h: a -> Unit with Fail(a), x: a): Unit = ();
    fn f(): Unit with Cell(E) = { let x = hole(());
      let r = fn(k) => { defer k(x); () }; r(fn(z) => put(z));
      call(fn(y) => fail(E), x) };
    fn main(): Int = 0;

Minimal fix: check `postponed` only in the second (final) `settleKeys`
call, for example with a flag or a separate final function. fix2 does
this; it still rejects every FX009 probe below with the same spans. Add
this program as an accepted case.

**I2. The span heuristic misleads, and the requested note is missing.**
`failureSpan` reports the first `fail` in the body, which can be
unrelated to the pair. Every new rejection has `related: []`, so there is
no note at the `Fail(a)` annotation that the brief and spec §6 ask for.
Programs (fix build):
- `type E = E; fn g(h: Int -> Unit with Fail(a)): Unit with Fail(E) = {
  handle fail(E) { fail(e: E) => () }; h(1) }; fn main(): Unit = ();`
  reports `fail(E` inside the handled `handle`. The cause is `h(1)`.
- `fn g(h: Int -> Unit with Fail(a)): Unit = (); fn main(): Unit with
  Console = { handle fail(E) { fail(e: E) => () }; g(fn(n: Int) =>
  fail(E)) };` reports the handled `fail(E)`. The cause is the `g(...)`
  call.
- `fn g(h: …Fail(a)): Unit = { let k = fn(n: Int) => h(n); () }` reports
  the whole block.

Minimal improvement: each postponed `RowPair` already carries `sides`. For
a pair a consumption postponed, `sides.left` is the consuming
expression's span (`Consume.consumeVia`: `origin.span`, e.g. `h(1)`).
Report the first remaining pair's `sides.left`. Where it is `nowhere`
(argument-against-parameter unification), pass the argument or call span
into `Sides` at that unification. Fall back to `failureSpan` only when no
span is available. Add a related note at the `Fail(a)` annotation (the
parameter's or signature's row entry). Test the exact span and note on
the two programs above.

## Minor / for the controller

- M1 (design question). A signature `Fail(a)` with a rigid `a` is still
  accepted when the body does not use it
  (`fn g(h: Int -> Unit with Fail(a)): Unit = ();`). Every caller is then
  rejected, even `g(fn(n: Int) => ())`, which fails nowhere (base
  accepted it), and the error is reported at the caller. Spec §2 says a
  rigid payload is E_TYPE. Rejecting at the annotation would be clearer
  and would make I2's note the primary span. This changes acceptance, so
  it needs a decision before anyone implements it.
- M2. The nested-fail row was retargeted, not weakened. The original
  9a6befd row checked that the walk reaches a nested `fail` inside an
  outer payload. With the fix, the mutant still rejects, but at the outer
  `fail`. I ran the mutant: it reports `fail(id(` (offset 67) on the old
  program and `fail(h(` on the new one, while the healthy build reports
  the inner `fail(e)`. The new span assertion detects the defect. The old
  program with a span assertion would have done so too, so changing the
  program was unnecessary. The rigid-inner case it dropped is now covered
  only by fx-handler-check's 'nested unresolved failure payload is
  visited' test, which checks code and message only and so no longer
  detects the walk mutant. Add the span to that test.
- M3. In the same change, BACKLOG FX009 is still Open, and there is no
  progress.md or findings entry (AGENTS.md: backlog current in the same
  change).
- M4. The comment at Failure.purs:54 says "(a rigid variable)". The pairs
  that are left over are also unsolved metas (instantiated callee
  `Fail(a)`), so "a meta or a rigid variable" is more accurate.

## Not regressions (same result on base and fix)

These are accepted on both builds: deferred keys that settle (`let raise
= fn(e) => fail(e); handle raise(E) {...}`); a concrete `Fail(E)`
parameter row; a Result-to-Fail helper per family; a generic
`Result(e, a)` map; a `...r` callback row; and `defer put(x)` plus `call`
with a meta that the immediate consumption binds. These are now rejected,
consistent with the spec: `Fail(a)` in the signature row with `h(1)` in
the body, and its concrete caller (which base accepted, unsoundly).

## Conformance

Failure.purs is 159 lines and purs-tidy clean; the new helper is small.
test/regression.mjs is 249 lines (at the limit). The tests were seen
failing on base. fx-fail-pairs uses `runGo` rather than `runGoBatch`,
which other fx tests also do (acceptable).
