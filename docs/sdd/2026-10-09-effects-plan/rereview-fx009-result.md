# FX009 re-review: c445bac + 33a3a62 (fx009, base 531e438)

Verdict: **Needs fixes**. The pair guard can still be reached, it is the
only thing that rejects a program that panics at run time, and nothing
tests it.

## What I ran vs read

Ran in worktree agent-a323eb1007714023e: `npm run build`; `node --test
test/fx-fail-pairs.test.mjs` (10/10); `node scripts/regression.mjs
signature-fail nested-fail` (both hold); `node scripts/regression.mjs`
(34 proofs); `npm run verify` (exit 0, 943/943 parallel, 29/29 serial);
`node scripts/waxwing.mjs run` on the program in N1.

Ran in scratch copies (scratchpad only, never in the repo): `base` (531e438
src); `noguard` (`settleFinal … >>= Right`, which drops the leftover-pair
check); `nom1` (the regression row's mutation of Row.purs). Each probe below
went through `Program.Compile.compile` and `wire` on all of these builds.

Read: AGENTS.md, docs/engineering.md (testing and regression sections), the
round-1 review, spec §2 "Label keys", and the diff (Row.purs, Failure.purs,
Postponed.purs, Unsettled.purs, Call.purs, Apply.purs, the tests, both
regression scripts), plus UnifyRow `consume`/`finish`/`postponed`,
`Domain.Type.Parts.typeHead`, `Domain.Row.labelKey`, and
Resolve/HandlerExpression `failureClause`.

## Prior findings

- I1 ADDRESSED. `settleFinal` runs only in the final settle. The round-1
  program now uses `Fail(a)`, so it is rejected at the annotation, which
  follows the M1 decision. The `Fail(Box(a))` variant is accepted. No
  program currently triggers the early rejection, so the dropped acceptance
  test is justified.
- I2 PARTLY. The guard now reports `sides.left`. A call argument also gets
  a note at the parameter row (`with Fail(Int -> Int)`). A consumption
  (`h(1)`, `defer h(1)`, `let k = fn(n) => h(n)`) is reported at the
  correct expression with no note, and so is an `applyValue` argument
  (`let g = fn(h: …) => (); g(fn …)`). In the handle-clause case
  (`handleRigidBody` below), the primary span is the payload `E` inside
  `fail(E)`, and the note "this failure has no concrete error family"
  points at the whole `handle`. That is misleading. None of these cases is
  tested (N1).
- M1 ADDRESSED for `TVar` payloads, in every written position: own row,
  parameter row, nested arrow, result row, `Handler(...)`, row argument,
  type declaration field. The tests check the span and the hint.
  `Fail(Error(a))` stays allowed. Lambda annotations cannot name a fresh
  `a`: they give `E_UNBOUND`, before and after the fix, so they are not a
  gap. The fix does not cover payloads that have no head (N1, N2).
- M2 ADDRESSED. The nested test moved to fx-fail-pairs with an `at` span
  assertion. The old rigid-inner program cannot be written any more,
  because `Fail(a)` is now refused at resolve.
- M3 NOT ADDRESSED. Neither commit touches BACKLOG.md, docs/progress.md or
  docs/findings.md, and FX009 is still `Open`.
- M4 ADDRESSED (Failure.purs comment).

## N1 (Important): the guard is reachable through payloads with no head

`typeHead` is `Nothing` for `TFun`, `THandler` and `TVar`. Row.purs
`concrete` rejects only `[ TVar _ ]`. So a signature can still write
`Fail(Int -> Int)`, its label never gets a key, and every pair that meets
it is set aside. A failing payload can never have one of these types,
because `firstUnkeyed` rejects `fail(fn …)`. Still, dropping these pairs
reproduces the original FX009 unsoundness:

    type E = E; fn g(h: Int -> Unit with Fail(Int -> Int)): Unit = h(1);
    fn main(): Unit with Console = g(fn(n: Int) => fail(E));

- `base`: accepted, and `run` gives E_TOOL `panic: no handler for Fail`.
- `noguard`: accepted.
- fix: E_TYPE at `h(1)`, from the guard alone.

Other programs only the guard rejects (fix: E_TYPE; `noguard` and `base`:
accepted):

- `g(h: … Fail(Int -> Int)): Unit = ()`, called with
  `g(fn(n: Int) => fail(E))`: reported at the lambda, note at the
  parameter row.
- `… Unit with Fail(E) = { handle fail(E) {…}; h(1) }`: at `h(1)`.
- `{ let k = fn(n: Int) => h(n); () }`: at `h(n)`.
- `{ defer h(1); () }`: at `h(1)`.
- Partial application `let p = g(1); p(fn(n: Int) => fail(E))`: at the
  lambda, no note.
- `let g = fn(h: Int -> Unit with Fail(Int -> Int)) => (); g(fn … fail(E))`
  (the `applyValue` path): at the lambda, no note.

So Postponed, Unsettled and the span stamping in both Call and Apply do
run, and they are load-bearing. They need tests. The implementer's
concern (a) rests on a wrong premise.

Two required changes:

1. **Tests.** Make the program above an acceptance-test failure, and assert
   the span and note for the call-argument, consumption and `applyValue`
   cases. Add a regression row that restores the dropped-pairs defect
   (the guard removed) and probes this program. Nothing proves the
   original FX009 defect any more, because postponed-fail was replaced.
2. **Decide first** (for the controller or user): extend the M1 rule to any
   payload with no head (`TFun`, `THandler`), refused at the written label.
   Spec §2 already lists the keys as "Int, Bool or a TypeId". Then the
   annotation becomes the primary span. Written but unused rows also need
   this: `fn f(): Int with Fail(Int -> Int) = 0;` and
   `fn g(h: Handler(Fail(Int -> Int))): Unit = ();` are accepted today.
   If this is adopted, the guard is probably unreachable again. My
   remaining sources were fail expressions, which `firstUnkeyed` checks
   first, and the clause case in N2. In that case, shrink the guard to a
   one-line rejection at `failureSpan` and drop Postponed, Unsettled and
   the stamping in Call and Apply. That is about 70 lines, plus 4 extra
   `where` bindings in `supplied`, which is now at 10 against an aim of 8
   and about 45 lines against an aim of 30. docs/engineering.md has no
   explicit "no untested code" rule, but AGENTS.md requires regression
   tests to be demonstrated, and the guard needs at least one probe that
   reaches it.

## N2 (Important, partly pre-existing): handle-clause payloads

`failureClause` resolves `fail(e: T)` through `resolveTypeWith`, not
`label`, so `concrete` never sees it. A clause with a rigid `a` or a
function payload type-checks and then crashes in specialization:

- `fn f(x: a): Int = handle 0 { fail(e: a) => 1 }; fn main(): Int = f(1);`
  gives E_INTERNAL `Fail without a family`
  (Specialize/Handlers.purs:112) on base, noguard and the fix.
- `fn main(): Int = handle 0 { fail(e: Int -> Int) => 1 };` gives the same
  E_INTERNAL on all three builds.
- `fn f(x: a, h: Int -> Int with ...r): Int with ...r = handle h(1)
  { fail(e: a) => 1 }; fn main(): Int = f(1, fn(n: Int) => n);`: fix
  E_TYPE (guard); noguard E_INTERNAL.
- `type E = E; fn f(x: a): Int = handle fail(E) { fail(e: a) => 1 }; …`:
  fix E_TYPE at `E`, with the note on the whole `handle` (misleading);
  base E_INTERNAL.

I found nothing unsound here. A clause `Fail(a)` never gets a key, so it
never matches a real `Fail(E)`. Without the guard, the callback case is
the sound E_EFFECT `Unhandled Fail(E)`. What is missing is a diagnostic:
an internal error reaches the user. Fix: apply the same no-head rule to
the clause payload in `failureClause`, at the clause type's span, with the
hint. Then add a test for each clause program above.

## Regression rows

signature-fail is a real proof. With the `nom1` mutation, the guard still
rejects the program, but at the lambda argument, so the probe fails with
`signature Fail family: wrong span`. That is the intended reason. I ran
nom1 on that program: E_TYPE at `fn(n: Int) =>…`.

nested-fail is not weakened, since it now checks the span. The original
FX009 defect (leftover pairs dropped) has lost its row. postponed-fail is
gone, and signature-fail mutates resolve, not the guard. Add the row in
N1.1.

## Conformance

All files are within 250 lines (test/regression.mjs 249). `supplied` in
Call.purs is over the `where` and length aims (see N1.2). No `let … in`
and no anonymous lambdas. M3's same-change backlog, progress and findings
updates are missing. Minor: `typeHead` gives `Unit` a key, but spec §2
lists only Int, Bool and TypeId (`Fail(Unit)` is accepted and runs). Align
the spec or the code.
