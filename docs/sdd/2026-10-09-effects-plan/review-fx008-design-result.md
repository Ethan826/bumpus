# Review: FX008 abort-tracking design note (docs/plans/2026-10-10-abort-tracking-design.md)

Reviewer: independent, adversarial. Date: 2026-10-10. Branch fx008.
No repository file other than this one was changed.

## Verdict: Accept with fixes

The core idea (one mark per label occurrence, clause-to-handler edges as
inequalities, signature constants with weakening-only opening) is sound as
far as I could push it: I found no program that defeats the *intended*
rule. But the note as written has two Critical gaps. Each one leaves
an unsound program accepted, and one of them is the note's own success
criterion (the cross-function program). Both can be fixed inside approach
A. There are also two Important precision regressions that the note does
not list. They come from marks being unified (invariant) at consumption and
installation, which contradicts §6 "Unchanged".

Evidence key: **[ran]** means probed with `node scripts/waxwing.mjs emit` (and
`go run` of the output) on the current compiler. **[read]** means reasoning
over the note, the spec and the checker source. Probe files are in the
session scratchpad, not the repo.

## Critical

**C1. The solver never checks handler marks that became N by unification.
The cross-function hole therefore stays open.** §3.5 seeds the worklist
only with "the mark of every non-`Fail` label in a deferred own row"
(step 1). Blocks and edges fire only "when a handler mark becomes N"
(step 3) through that worklist. A handler mark meta can also become N by
plain unification with a signature constant, with no demand involved:
- a callee's own-row `nofail L` at a call site;
- a `Handler(nofail L …)` parameter, which is not opened (§3.4 opens only
  M parameters);
- a declaration result `Handler(nofail L …)` unified with the body's
  `handler` expression;
- an N label in R, or a `Handler(nofail …)` field.

None of these reaches the worklist, so its blocks are never checked.
Programs:
```
type E = E; effect Log { fn log(n: Int): Unit; };
fn work(): Unit with nofail Log = { defer log(1); () };
fn main(): Unit with Console =
  handle with handler Log { log(n) => fail(E) } { work() }
  { fail(error: E) => print(9) };
```
`main` has no deferred row, so there is no demand. The lexical handler's
meta becomes N through `work`'s constant, and its Fail block is never
consulted. The program is accepted. It is §1's cross-function form, and
today it is accepted and exits 1 with `fail(E): E` [ran, without
`nofail`]. The same applies to
`fn mk(): Handler(nofail Log) = handler Log { log(n) => fail(E) };` and to
`run(handler Log { log(n) => fail(E) })` with
`fn run(h: Handler(nofail Log)): Unit = with h { defer log(1); () }`
[read]. §5 step 2 ("If m resolves to N, propagation made every label …
N") silently assumes seeding that §3.5 does not provide.

Fix:
- Seed the solve with every mark that *resolves* to N from any source
  (constants and demands alike), and check every block and edge whose
  handler mark resolves to N.
- Record, for each mark meta, the first source that made it N (a call
  span, a `defer`, a parameter or result annotation). The §3.6 primary
  span "the call whose nofail label met …" needs it, because the error
  is now found at solve time, not at a unification failure.
- Add the mutant "seeding dropped ⇒ cross-function program accepted".

**C2. Clause own rows need a late consumption that keeps `Fail` and runs
to a fixpoint. The note specifies neither, and copying `settleDeferred`
would be unsound.** Today a clause is checked against R itself
(Handler.purs:38,71). So labels that reach the clause row after the
`handler` expression is checked are in R automatically, and they reach
every installation. For example:
```
fn main(): Unit with Console = {
  let mk = fn(g) => handler Log { log(n) => g(n) };
  let h = mk(fn(n: Int) => fail(E));
  with h { log(1) } };
```
Today this is correctly E_EFFECT `Unhandled Fail(E) in main` [ran]. Under
§3.4 the clause's own row is `g`'s row meta, which gets `Fail(E)` only
when `mk` is applied, after the clause labels (none yet) were consumed
into R. Unless that late label is consumed into R, R never gets `Fail(E)`.
The program is then accepted and fails with no handler at run time: the
plain effect system becomes unsound, not just `defer`.

The only late mechanism today, `settleDeferred`, does three things that
are wrong for clause rows:
- it filters `Fail` out of late labels (Defer.purs:114);
- it judges every deferral before any late consumption (Defer.purs:102-103);
- it runs one pass in registration (post-)order.

A clause's R can alias a row that was registered *earlier*. For example,
a handler expression written after a `defer with h { … }` reaches it
through a lambda parameter whose handler type was fixed earlier. In that
case a single pass misses labels (the reversed-order variant is [read]
only; my attempt to write it hit `Expected a handler` because `with`
needs a known handler type).

Fix. In §3.4/§3.5, state one list of restricted rows (deferrals and
clauses) and this order:
1. Late consumption to a fixpoint. It is monotone and bounded by the
   labels. Clause rows keep `Fail`, which is consumed into R.
2. Judge the defers (`Fail` and rigid tail).
3. Solve the marks (C1).
4. Run the entry check.

Tests: the program above, and the reversed-registration form. Mutants:
"clause late consumption dropped" and "`Fail` filtered from clause late
labels".

## Important

**I1. Marks are unified at consumption and installation, which merges the
marks of unrelated handlers. Defers under fail-free handlers are then
rejected, contradicting §6 "Unchanged".** §3.5 replaces unification with
⊑ only between clause labels and their handler. Everywhere else marks
unify (§3.4 "Lambdas … no change"). A local lambda or a let-bound handler
used under two handlers therefore identifies their marks:
```
type E = E; effect Log { fn log(n: Int): Unit; };
fn main(): Unit with Console =
  handle {
    let k = fn(n: Int) => log(n);
    with handler Log { log(n) => print(n) } { defer log(1); k(2) };
    with handler Log { log(n) => fail(E) } { k(3) }
  } { fail(error: E) => print(9) };
```
Today this is accepted and prints `2 1 9` with no cleanup abort [ran].
Under the design, `k`'s row gives m_print = m_fail. The defer demands
m_print = N, which reaches the failing handler's block, so the program is
rejected. The error names a handler that no cleanup reaches.

The same happens with `let fwd = handler Log { log(n) => log(n + 10) };`
installed once under the printing handler with `defer log(1)` and once
under the failing one. Today it is accepted and prints `11 9` [ran].
Under the design, R ≡ both outer rows, so x = m_print = m_fail and the
program is rejected.

Neither case is in §6 or L1, since L1 is about nested M in parameter
types. Fix: either
- (a) list this as a limitation, with the workaround (a declaration is
  opened per use) and a note in the diagnostic ("this function value is
  also used under the handler at …, which may fail"); or
- (b) make consumption and `with` directional (current ⊑ stage, and
  ρ ⊑ R). The caveat for (b): when consumption binds a stage row's meta
  tail to the rest of the current row, labels are shared by identity, so
  (b) also needs fresh mark copies plus edges on tail binding.
  Otherwise the merge comes back for labels that arrive through tails.

The §3.5 claim that inequality avoids spurious errors holds only for the
clause-to-handler edge, and the note should say so.

**I2. Marks are not polymorphic and R is invariant, so a forwarding
handler cannot be written once.** Intercept-and-forward is decision 8 and
spec §5 probe 3, and prefixing loggers are in FX001 scope. The honest type
of a prefixing handler is "N exactly when its outer Log is N", and the
type language cannot express that. Program, accepted today, prints
`101 101 0 9` [ran]:
```
fn prefix(): Handler(Log with Log) with pure = handler Log { log(n) => log(n + 100) };
fn run(h: Handler(Log with Log + ...e)): Unit with Log + ...e = { defer log(0); with h { log(1) } };
// main: `with prefix() { defer log(1); () }` under a printing handler;
//       `run(prefix())` under a printing handler;
//       `with prefix() { log(3) }` under a failing one, inside handle
```
Under the design no signature works for all three uses:
- As written, `prefix` is M, so the first defer is rejected.
- `Handler(nofail Log with nofail Log)` cannot be installed under the
  failing outer, even though no defer is involved there: R's N unifies
  the outer meta to N, which is then blocked.
- `run` needs `nofail Log` for its `defer log(0)`, and then R's M Log
  mismatches its own N Log. Installing a handler that assumes nothing
  under an N outer is safe, but invariance rejects it.

Fix: record this as limitation L4, with the workaround (two helpers).
Or admit mark variables in signatures (`Handler(k Log with k Log)`,
quantified with equality only and instantiated fresh per use), with a
demand on a rigid k being an error. That stays per-declaration and
carries no scheme constraint, and it is the natural partner of C as
elaboration. At a minimum, make the `with` consumption of R directional
(ρ ⊑ R), which fixes `run`.

**I3. §6 understates the migration.**
- `nofail` spreads up the call chain. A caller written `with Log` that
  calls a `nofail Log` function mismatches (N constant against the
  caller's M constant). So every declaration between the cleanup and the
  installing declaration must write `nofail`, which matters for the
  Task 11 scenario.
- A handler whose clause calls any callback, or a local lambda whose row
  ends in a declaration's ambient, can never be N (rigid-tail block).
  So cleanup cannot perform its label.

List both, plus I1 and I2, under "Newly rejected". Make A1 an explicit
user decision (D0), since it is an interpretation.

**I4. The §5 argument needs restating.**
- (a) It depends on C1 and C2.
- (b) Step 1's "callee N labels meet only N marks" is false at
  unification time: they meet metas, possibly blocked ones. Honesty comes
  from the solve, not from unification.
- (c) State the invariant for every occurrence (the k-th occurrence of a
  key describes the k-th frame for that key). Clause contexts reach
  non-first frames, and the induction for `with` shifts occurrences.
- (d) Closing unsolved mark metas to M is harmless only because every
  value leaving a declaration passes through signature constants. That
  is the same escape argument the rigid-tail rule needs, and it should be
  stated.
- (e) Late consumption (C2) belongs in step 1, bullet 4, because the
  clause's row is no longer R.

## Minor

- **M1. Wrong module.** §10 names Instantiation for the opening positions.
  Opening is in Features.Check.Use `declarationUse` and Stages
  `openedRow`; Instantiation.purs is the ADR 007 rule. Its `admissible`
  must ignore marks inside type arguments.
- **M2. Marks in types.** The `THandler` label mark lives in a *type*, not
  in row structure. Specialize keys use derived Ord on types, so strip
  marks at the Check→IR boundary, or `Handler(N Log)` and `Handler(M Log)`
  become separate keys. Label is built or matched at about 100 sites in
  about 20 modules [ran: grep], so the §10 estimate is likely low.
- **M3. Console and Fail conventions.** "A written label is M unless
  `nofail`" (§3.4) contradicts "Console is always N" (§3.1). Normalize
  Console to N at resolution, including `print`'s label, or every
  `with Console` program mismatches. Give Fail labels a fixed mark that
  is never compared. Specify how unsolved mark metas print (as plain `L`).
- **M4. §4.6.** "A ctl clause that does not resume makes its handler M"
  cannot be decided. A clause can resume and then fail, or drop the
  continuation conditionally. Say instead: any `ctl` clause makes its
  handler M until the general-resume milestone proves otherwise.
- **M5. §4.3.** "Consistent with R" is ambiguous. Decide whether a written
  `Handler(nofail Log with Fail(E))` is E_TYPE or merely an over-wide R.
  It is sound either way.
- **M6. D3 rationale.** Without position 2, a handler meta passed to an M
  parameter just becomes M; it conflicts only when it is also demanded N.
  Position 3 matters mostly for joins (`if` or `match` with M-typed
  values).
- **M7. §4.4 wording.** "A child performs no operation" should read
  "performs no operation that reaches a parent frame". A child may handle
  its own operations internally.
- **M8. Diagnostics without `defer`.** Separate clause rows change today's
  diagnostics for some rejected programs without `defer`. Example: a
  clause calling a local lambda that is also used in the body, which is
  today `Console + ... and Log + Console + ... cannot be made equal`
  [ran]. Acceptance is unchanged, but exact-text tests may move. Say so.
- **M9. Oracle and generators.** Instead of teaching the generator about
  marks, add a one-directional soundness differential: generate failing
  clauses and defers without restriction, and assert that compiler
  acceptance implies the oracle never reports
  `typed abort escaped cleanup`. This tests §5 directly. Keep the pinned
  oracle test (oracle only) and add a compiler-rejection assertion for the
  same source.
- **M10. FX007.** For §4.5, `nofail ...e` has to be carried as a
  constraint on row metas through tail unification inside a declaration,
  not only "checked at instantiation". It stays local, but say so.

## Alternatives (§2)

A is well-founded. B forbids failing implementations of any effect used
in cleanup, which is too strong given the user's "without restricting
effectful cleanup". C conflicts with A2.

I found no simpler sound design that meets the constraints. One possible
reduction: drop `nofail` on the handled label of `Handler(…)` types (so
handler values that cross declarations are always M, while position 2 is
kept), with marks only in own rows and R. That is simpler, but it breaks
handler injection through helper functions, which Task 11 likely needs.
The missing piece is mark polymorphism (I2), not a different approach.

## Verified versus read

- [ran] The cross-function hole is accepted today and exits 1 with
  `fail(E): E`.
- [ran] The programs in I1 (lambda and let-bound handler) and I2
  (forwarding helper) are accepted today and run correctly.
- [ran] The C2 program is rejected today with `Unhandled Fail(E) in main`.
- [ran] A clause calling a body-shared local lambda is rejected today, in
  both the `main` and non-`main` forms.
- [read] Everything about the proposed rules, the C2 reversed-order
  variant, and the soundness search. I checked:
  - handler values in parameters, results, fields and row-parameterized
    data;
  - opening positions 1-3 and their variance;
  - escaping lambdas, ambient and named rows;
  - nested and forwarding handlers;
  - `handle` inside cleanup and handlers installed inside cleanup;
  - staged and partial application;
  - recursion, deferred Fail keys, and operations carrying `Handler`
    types.

  Beyond C1 and C2, none of these produced an accepted program whose
  cleanup ends in a typed abort.
