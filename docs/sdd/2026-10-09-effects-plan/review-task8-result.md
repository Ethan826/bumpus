# Review: FX001 Task 8 (`defer`, `crash`, cleanup, defect report), 041cb31

Scope: the BASE..041cb31 diff without the docs snapshot 84fd420. Spec §2
(`defer` rule), §3, §4 "Uniform ctx", §5 "Defect report", the Task 8 brief
and the context rulings. I ran
`GOTOOLCHAIN=go1.26.4 node --test test/fx-cleanup.test.mjs` (25/25 pass) and
node probes through `output/Program.Compile`. The Go for those probes was
built and run under `.build/review8/`. I made no changes to the working tree.

### Spec Compliance

- ✅ Syntax, parse and resolve. `defer e` is a block item. Using it as the
  last item without `;` gives E_SYNTAX `Expected ;`
  (src/Format/Parse/Block.purs `valued`). `crash` is a builtin global
  resolved like `print`.
- ✅ `crash(value: a): b`. It takes one argument (E_ARITY otherwise). The
  result is a fresh type and it performs no effect. The argument is judged
  by Check.Printable with its existing text
  (src/Features/Check/Operation.purs crashCall/crashRef,
  src/Features/Check/Printable.purs). Bare `crash` works (probe P12:
  `app(crash)` reports `crash: 3`).
- ✅ The spec's examples are rejected: an unhandled Fail performed directly,
  through a call, or through a deferred key (whatever the signature says),
  and a non-Unit `defer`. The span covers the whole item and is stated in
  the report.
- ❌ **§2 "a Fail(E) that e performs … whatever E's key" and §3 "no typed
  error is ever lost or converted" are violated.** Ordinary programs that
  fail inside cleanup are accepted, and at runtime a recoverable typed abort
  becomes an uncatchable defect. src/Features/Check/Defer.purs:44-63 judges
  the row only at the `defer` and then unifies it with the current row
  (`consumeAt … row`). See Critical 1.
- ✅ Evaluation and registration (src/Format/Go/Block.purs). The closure is
  appended when the item is reached; an unreached `defer` never runs (test).
  The whole expression is evaluated at exit, and cleanup runs LIFO (index
  descending in `waxwingCleanup`).
- ✅ Cleanup context. The closure captures the block helper's `ctx`, which is
  the registration context, since block items never change `ctx`. Probe P9:
  a `defer log(1)` registered inside an inner `with` while an abort unwinds
  prints `101` then `9`. The test with the outer registration prints `1`,
  `9`.
- ✅ Exactly once per exiting activation. Each helper call has its own
  `waxwingCleanups` slice and its own Go `defer`.
- ✅ Cleanup failures (defects only). The pending cause is kept first, later
  causes follow in execution order, the remaining closures still run (each
  in `waxwingRun`), there is one report and exit status 1. With no new cause
  the pending panic is re-raised unchanged, so an abort still reaches its
  `handle` (test "cleanup handling its own failure while an abort is
  pending").
- ✅ Defects are uncatchable by `handle`: `waxwingHandle` re-panics anything
  that is not its own marker (test).
- ✅ Report format: `crash: V`, `fail(T): V` with type arguments
  (`Error(Int)`), `no handler for L` (F7, injected test), `\n` escaped,
  stderr, exit 1. `<not printable>` is decided statically
  (src/Format/Go/Report.purs `holdsFunction`, iterative).
- ✅ Uniform ctx (§4). `defer`/`crash` do not force `ctx` (test "defer and
  crash need no context"). The runtime, the `os` import and main's
  `defer waxwingReport();` are emitted only when `usesDefects` holds. A
  block without `defer` emits no Go `defer` (test). `waxwingFail` passes
  `nil` as `report` otherwise.
- ✅ Global constraints. bootstrap/ is untouched and the IR import
  allowlists (test/structure.test.mjs) are untouched. Existing diagnostics
  are unchanged; only the new `DeferMayFail` is added.
- ⚠️ Not verified here: the full verify and regression runs. I rely on the
  implementer's logs, whose failures are all in the known timing set.

### Strengths

- The runtime is small and matches the §4 contract: recovery happens directly
  in the deferred function, each cleanup runs in `waxwingRun`, and the
  pending cause is re-raised unchanged when nothing new happened. The
  "emitted only when used" boundary is clean (`Shape.defects`).
- The tests pin stdout, stderr and status exactly for every run case,
  including multi-cause ordering across nested blocks and the injected F7
  guard. Mutation evidence is reported per property.
- `holdsFunction` is iterative and guards cycles, so it matches the
  codebase's no-stack conventions.
- The implementer documented the gaps honestly (concerns 1–3 are all real).

### Issues

#### Critical

**1. `defer must not fail` is not sound; typed aborts escape cleanup and are
converted into defects.** (src/Features/Check/Defer.purs:44-63; runtime
consequence in src/Format/Go/Cleanup.purs `waxwingCleanup`/`waxwingRun`.)

Why this is a spec violation and not just an incomplete diagnostic: §3
"Cleanup failures" justifies the whole policy by the static guarantee
("section 2 rejects … so a typed failure pending while the block unwinds
always reaches its own `handle`, and no typed error is ever lost or
converted"). At runtime, an abort that escapes a cleanup closure is caught
by `waxwingRun` and recorded as a defect cause. That is the alternative the
user explicitly rejected on 2026-10-09: "converting a pending abort into an
uncatchable defect on a typed cleanup failure". Classes P1/P2 are the
ordinary bracket/`finally` pattern, not corner cases.

The following programs are accepted at 041cb31. Each was compiled and run;
the output is shown after it.

```
P1 (ambient row, the plain bracket pattern):
type E = E; fn bracket(release: Unit -> Unit): Unit = { defer release(()); () }; fn main(): Unit with Console = handle bracket(fn(_) => fail(E)) { fail(error: E) => print(9) };
=> status 1, stdout "", stderr "fail(E): E\n"   (the enclosing handle never sees it)

P2 (named row variable):
type E = E; fn bracket(release: Unit -> Unit with ...e): Unit with ...e = { defer release(()); () }; fn main(): Unit with Console = handle bracket(fn(_) => fail(E)) { fail(error: E) => print(9) };
=> status 1, stderr "fail(E): E\n"

P3 (earlier closure whose Fail key was unsettled at the defer):
type E = E; fn main(): Unit with Console = handle { let f = fn(x) => fail(x); let g = fn(y) => { defer f(y); () }; g(E) } { fail(error: E) => print(9) };
=> status 1, stderr "fail(E): E\n"

P4 (shared lambda meta; Fail arrives after the defer is checked):
type E = E; fn main(): Unit with Console = handle { let run = fn(h) => { defer h(()); () }; run(fn(_) => fail(E)) } { fail(error: E) => print(9) };
=> status 1, stderr "fail(E): E\n"

P5d (a pending, *handled* typed abort is converted, which is exactly the rejected alternative):
type E = E; type F = F; fn bracket(release: Unit -> Unit with ...e, body: Unit -> Unit with ...e): Unit with ...e = { defer release(()); body(()) }; fn main(): Unit with Console = handle { handle bracket(fn(_) => fail(E), fn(_) => fail(F)) { fail(error: F) => print(8) } } { fail(error: E) => print(9) };
=> status 1, stderr "fail(F): F\ncleanup failed: fail(E): E\n"   (both handles are bypassed; expected per spec: compile error)
```

Root cause: `checkDefer` judges the deferred row R_d once, at the `defer`,
and then `consumeAt` unifies R_d with the current row ρ. After that, R_d and
ρ are the same row. Anything e performs through a meta that is decided later
(P3, P4) can no longer be told apart from what the rest of the function
performs. A rigid tail (the ambient row or `...e`, P1/P2/P5d) can be
instantiated with `Fail` by any caller, and the definition site never sees
it.

Proposed rule (implementable within the current checker):

1. **Keep e's row separate and judge it after settlement.** Infer e against a
   fresh meta row δ, as now. At the `defer`, consume only δ's *resolved
   labels* into ρ (unify `labels + fresh` with ρ, the closed-row coercion).
   Do **not** unify δ's tail with ρ. Record `{span, δ}` in
   `State.deferrals`. After `settleKeys` (where `rejectDeferred` runs now),
   resolve δ fully:
   - (a) any `Fail` label at all is E_EFFECT
     `defer must not fail, but it performs Fail(T)`;
   - (b) labels that arrived after the `defer` and are not Fail (e.g. Log
     through a shared meta) are consumed into ρ then, and settled once more
     before the Entry check;
   - (c) an unbound remaining tail is closed to empty.

   This catches P3 and P4, because the late Fail lands in δ, which is no
   longer the same row as ρ. It also removes the postponed-pair scan, and
   with it false positive (b) below: a Fail handled inside e never reaches δ.
2. **A deferred row whose tail resolves to a rigid row variable** (the
   ambient row or a named `...e`) can be instantiated with `Fail` by any
   caller, so it must be rejected (P1, P2, P5d). It cannot be accepted
   without a "lacks Fail" predicate on row variables. Two options:
   - Rejecting it is sound but strict. A deferred callback parameter must
     then be `with pure` (or e must not call it), because `with L` without a
     spread still carries the ambient row. The message has no text in the
     spec (the spec only gives `performs Fail(E)`), so the exact wording
     needs a user/controller ruling, e.g.
     `defer must not fail, but it performs ...e`.
   - Sound and precise: a lacks-Fail constraint on row variables that are
     consumed by a deferred expression, checked when callers instantiate
     them. That is a design/ADR change (qualified rows).

Program classes that still escape under 1 alone: every rigid-tail case
(P1, P2, P5d). Under 1+2: none that I can construct. Handler clauses and
lambdas reach δ only through metas or rigid tails, and both are covered.
Function values stored in data types carry declared row parameters, which
are rigid inside the definition and so fall under 2.

Recommended disposition: escalate 2 to the user (it restricts the bracket
idiom or needs predicates) and implement 1 in this task. Until 2 is decided,
add a BACKLOG item and change §3's "no typed error is ever lost or
converted" claim. The tests should add P1–P4 as rejections (P1/P2 under
whichever text is ruled).

#### Important

**2. `payloadName` recurses along arrow spines, and the compiler overflows the
JS stack.** (src/Format/Go/Report.purs `payloadName`, the `arrow` branch.) The
nesting limit (128) bounds nesting of type arguments; it does not bound arrow
spines. Reproduced:
`type Error(a) = Error(a); fn work(f: Int -> … (5,000 arrows) … -> Int): Unit with Fail(Error(<same arrow>)) = { defer crash(1); fail(Error(f)) }; fn main(): Unit = ();`
throws `RangeError: Maximum call stack size exceeded` (also at 20,000). The
same program without `defer` compiles. AGENTS.md and the fn-scale targets
(5,000 parameters) require spines to be walked by a loop.

Fix: collect the spine's parameter names in a loop (as Format.Diagnostic
`arrowName` and IR `spine` do). Build `FunctionName` with a `foldr` over that
array, and only recurse into arguments of type applications, which the
nesting limit bounds. Add a 5,000-arrow payload test.

**3. False positive: a `defer` that handles its own Fail with a
still-unsettled key is rejected.** (src/Features/Check/Defer.purs
`postponedPayloads`, which scans every postponed pair created during the
defer, including those inside a handled `handle` body.) Reproduced:
`type E = E; fn pick(): a = crash(0); fn main(): Unit with Console = { let p = pick(); defer handle fail(p) { fail(error: E) => print(1) }; match p { E => () } };`
gives E_EFFECT `defer must not fail, but it performs Fail(E)`. The same
expression as `let _ = …` compiles and runs. This contradicts §2's own
example form (`defer handle … { fail(e: …) => () }`). The shape is rare
(unannotated payload whose key is settled later), but it is a wrong
rejection. Fix: use rule 1 above (judge resolved δ, not postponed pairs).

#### Minor

- Commit 041cb31's trailer reads `Co-Authored-By: Claude Sonnet 5.5`; the
  context requires `Claude Opus 5.5`. Fix this in the next commit's
  trailers; do not rewrite history unless the controller asks.
- Unspecified conventions that should be recorded in docs/findings (the
  controller must do this, since docs are off-limits to the implementer):
  - With no pending cause, the first cleanup crash is the unprefixed first
    line (`crash: Slow\ncleanup failed: crash: Busy`).
  - Go runtime panics render as `panic: <text>`.
- Report `described`/`abortReport` embed the type name in a Go string
  literal without escaping. Type names are identifiers, so this is safe
  today. A one-line comment would protect it against future quoted names.
- (d) Deviations, each judged:
  - `Format.Go.Cleanup` and `Format.Go.Report` instead of `Context.purs`:
    justified by the 250-line cap and F19.
  - `IR.TypeInfo.arguments`: needed to name `Error(Int)`, and it adds no
    module import (the allowlists are unchanged).
  - `specialize.test.mjs` `arguments: []`: the identity test still asserts
    equality, now with the monomorphic expectation stated, so nothing is
    weakened.
  - go-batch guard: the optional prefix is the exact
    `defer waxwingReport(); ` text and the count is still `=== 1`. The
    rewrite to `func Main() { ` keeps the `defer` inside `Main`, and each
    case runs as its own process, so `os.Exit(1)` is safe. It is not a
    weakening, beyond accepting the prefix on programs that lack the
    runtime, which `go build` would then reject anyway.

### Assessment — Task quality: **Needs fixes**

The runtime, report and emission policy are good and match §3–§5. The static
half of the `defer` rule is not sound: the bracket pattern (P1/P2) and two
meta classes (P3/P4) compile. At runtime they turn handled typed failures
into uncatchable defects, which is what §3 and the user's 2026-10-09
decision exclude. Fix Critical 1 (rule 1 now, rule 2 after a user ruling on
rigid tails) and Important 2–3 before approval.
