# Tracking handlers that may fail: design (FX008)

Status: design note, revision 6 (2026-10-10). Awaiting one Opus review,
then the user's written-spec approval. Not implemented. It amends the
effects spec (docs/plans/2026-10-09-effects-design.md) §2 and §3, and
CF001 §5/O-2/§8A (D4), when approved.

History:
- Revision 1 applied the Opus review (review-fx008-design-result.md: C1,
  C2, I1-I4, M1-M10).
- Revisions 2-3 applied the re-review (rereview-fx008-design-result.md:
  N1-N5).
- Revision 4 rewrote the late-consumption step after outside advice (§12).
- Revision 5 adopted the focused termination review's corrected procedure
  (review-fx008-termination-result.md: P1-P4, T1), not yet second-checked.
- Revision 6 records the user's decisions (§11) and adds D6 (mark
  variables, `nofail(k) L`) and D7 (directional checking). D7 required
  two structural changes, which also remove limitations L4 (mostly) and
  L5:
  - `with` consumes the handler's clause row R as a restricted row instead
    of unifying it with the context;
  - each installation gets its own *frame mark*.

  Mark solving becomes a path check over a two-point lattice with rigid
  variables (§3.5 step 5).

## 0. Understanding

What the user said (2026-10-10):
- The strict rule "a deferred expression cannot end in a typed abort"
  (spec §3) is unsound. Cleanup may perform an operation whose handler
  clause fails, and that handler may be installed by a caller in another
  function.
- Do not weaken the language's structure or design. In particular, do not
  deliver or convert cleanup aborts at run time.
- Fix it with type-level tracking. Performing an operation under a
  handler whose clauses may fail is known to possibly abort. That fact is
  carried through effect rows and across calls, so the `defer` check is
  sound without restricting effectful cleanup.

Interpretations, put to the user as decision D0 (§11):
- A1. "Without restricting effectful cleanup" means cleanup may still
  perform any non-`Fail` effect, provided the handler that receives it
  cannot fail. It does not mean that no accepted program changes. Programs
  that rely on an unknown handler not failing are exactly the unsound ones,
  so they must state that reliance. §6 lists every change.
- A2. Signatures stay the complete contract (P001: mandatory, rigid), so
  information that crosses a call appears in written types.
- A3. Runtime behaviour and Go output do not change. This is a
  checking-only change.

Success criteria:
- The pinned program (test/fx-oracle.test.mjs, `a cleanup ending in a
  typed abort is an interpreter error`) and its cross-function form (§1)
  are E_EFFECT.
- No well-typed program ends a cleanup in a typed abort (§5).
- Programs without `defer` keep their acceptance and meaning. Only
  diagnostic texts may move (§6).
- `bootstrap/*.go` and emitted Go stay byte-identical.
- Task 10's generator may emit failing random clauses.

## 1. The hole

```
type E = E;
effect Log { fn log(n: Int): Unit; };
fn work(): Unit with Log = { defer log(1); () };   // accepted today
fn main(): Unit with Console =
  handle with handler Log { log(n) => fail(E) } { work() }
  { fail(error: E) => print(9) };
```

The deferred row is `Log`, which contains no `Fail`. The clause runs in
its `with`'s outer context, where `Fail(E)` is handled, so it
type-checks. At run time the cleanup ends in `fail(E)`, and the program
exits 1 with `fail(E): E` (reviewer, run on the current compiler). The
deferred expression's own row cannot reveal this, because the failure
belongs to whichever handler a caller installs. `with h { body }`
consumes `h`'s clause row into the row outside the `with`, but the `Log`
the body sees records nothing about whether `h`'s clauses can end in an
abort.

## 2. Approaches

**A. A mark on each label occurrence (recommended).**
- `nofail L` means the handler frame that receives L cannot end an
  operation in a typed abort. Plain `L` promises nothing.
- Installing a handler gives the body's `L` that handler's mark.
- A signature that relies on a handler not failing writes `nofail`. Row
  unification then carries the reliance across calls.
- `defer` demands `nofail` on every label it performs.
- The mark is precise per installation, so one effect can have both
  failing and fail-free handlers.
- Cost: a contextual marker, separate clause rows, and a small
  propagation inside each declaration (§3.5).

**B. Totality declared per effect.** Write `effect nofail Log { … }`.
Every handler of such an effect must have fail-free clauses, and cleanup
may perform only these effects and Console. This needs no new type
machinery. But it forbids a failing implementation of any effect that
cleanup uses, which restricts effectful cleanup. It also forces effect
splits such as `Database`/`DatabaseRelease`. Totality per operation does
not work, because rows track effects, not operations.

**C. A with inferred marks.** Signature marks would be inferred from
bodies, so no annotations are needed. The cost: signatures stop being
the contract, checking needs the call graph's SCC order and a fixpoint,
and errors surface at distant installations. This conflicts with A2. It
could later elaborate onto A's representation.

Rejected outright:
- Putting the clause's `Fail(E)` in the body's row. A `handle` inside the
  body would then appear to catch an abort that targets one outside the
  `with`, contradicting clause context (spec §3).
- Delivering or converting cleanup aborts at run time (user decision).
- Whole-program flow analysis. It is not type-level and is imprecise
  through first-class functions.
- Recording a full failure row on each label. One bit is all that `defer`
  needs, and provenance can name the failure type `E`.

The reviewer found no simpler sound design that meets the constraints.
The reviews' remaining gap in A, mark polymorphism and directional
checking, is filled in revision 6 (D6, D7).

## 3. Design (approach A, revision 6: D6 and D7 included)

### 3.1 Meaning and invariant

A *mark* says whether a handler frame can end an operation in a typed
abort, meaning one that escapes the clause. `nofail` (N) means it cannot.
May-fail (M) is a plain label, which promises nothing. A clause may fail
and handle the failure inside itself. Defects and divergence remain
possible everywhere (spec §1).

Marks appear in two roles:
- **On a row label: an assumption.** `with nofail Log` on a computation
  means it assumes the Log frame it runs under is N. Its cleanup may then
  perform Log.
- **On a handler type: its own-abort mark.** `Handler(nofail Log with R)`
  says the handler's clauses cannot abort *by themselves*: no escaping
  `fail`, and no call through an unknown (rigid) row. Whether an
  installed frame aborts also depends on the outer frames its clauses
  reach. That is computed per installation (§3.4 `with`).

Invariant: suppose an expression is checked under current row ρ, and the
k-th occurrence of key κ in ρ is marked N (for every value of the
declaration's mark variables). Then whenever the expression runs, the
k-th frame for κ in its dynamic context cannot end an operation in a
typed abort.

Console is always N, because the runtime is its only handler. `Fail`
labels carry no mark.

### 3.2 Syntax

`nofail` is contextual, like `pure`. It is recognized directly before a
label in a row (after `with`, after `+`, or at the start of a row
argument) and as the handled label of `Handler(…)`. Elsewhere it is an
ordinary name.

`nofail(k) L` (D6) writes a *mark variable* k:
- It is implicitly quantified per signature, like lowercase type
  variables.
- It is a separate sort, so using `k` as a type is a sort error.
- It is allowed anywhere in a function signature: own rows, parameter
  rows, handler types and row arguments.
- It is not allowed in `type` or `effect` declarations in FX008 (L6).

```
fn work(): Unit with nofail Log = { defer log(1); () };
fn prefix(): Handler(nofail Log with Log) =          // own-abort free
  handler Log { log(n) => log(n + 100) };
fn around(body: Unit -> Unit with nofail(k) Log + ...e)
  : Unit with nofail(k) Log + ...e = with prefix() { body(()) };
```

Special cases:
- `nofail Fail(E)` is E_TYPE.
- `nofail Console` is accepted as redundant.
- `nofail ...e` is E_SYNTAX, reserved for FX007 (D5).

Row display prints `nofail L`, `nofail(k) L`, or a plain `L`; unsolved
marks print plain.

### 3.3 Representation

- `Label EffectRef (Array t)` gains a mark: N, M, a rigid mark variable,
  or a mark meta. Mark metas live in the checker substitution, and
  `resolvedRow` resolves them.
- A declaration reference instantiates the declaration's mark variables
  with one fresh meta each, shared across its signature.
- Console labels are normalized to N at resolution, including the label
  `print` consumes. `Fail` labels carry a fixed placeholder that is never
  compared.
- Label keys are unchanged.
- Marks are stripped at the Check-to-IR boundary. This includes the
  handled label inside `THandler`, so specialization keys never split on
  marks. Instantiation's `admissible` (ADR 007) ignores marks.

### 3.4 Typing rules (changes to spec §2)

Marks are constrained by equalities (type unification, as for any part of
a type) and by inequalities x ⊑ y, read "x is at least as strong as y",
with N ⊑ M. Every rule below is one of these two forms. §3.5 step 5 solves
them.

**Written labels** are M unless written `nofail` or `nofail(k)`, except
Console (§3.3).

**Consumption is directional (D7).** Consuming a stage row s into the
current row ρ (spec §2 "Consumption and opening") matches labels by first
occurrence, as today. For each matched pair it imposes ρ's mark ⊑ s's
mark: the frames must be at least as strong as the computation assumes.
When consumption binds s's tail meta to the rest of ρ, the labels bound
are fresh *copies* of ρ's remaining prefix labels: the same effect and
arguments, each with a fresh mark meta c and an edge ρ-mark ⊑ c. ρ's tail
itself stays shared. Without copies, a monomorphic local's row would
share marks with the first context it is used in, and so merge unrelated
handlers (review I1). Outside consumption, rows inside types unify with
equality, as today (function types are invariant).

**Opening at declaration use** (Use `declarationUse`, Stages
`openedRow`) applies only to handler types (D3), because types unify by
equality:
- an M handled label in a top-level parameter type;
- an N handled label in the top-level result type.

Each becomes a fresh meta. Directional consumption covers the former
"own-row M" position, so it needs no opening. Callback rows in
parameters are never opened, which would be unsound.

**`handler L { clauses }`** has type `Handler(m L with R)`, with m and R
fresh:
- Each clause is checked against its own row, consumed into R. This is
  the R0 technique; late labels are consumed in §3.5 steps 1-3, and
  `Fail` is kept.
- R is therefore exactly the clauses' effects. Its unsolved tail closes to
  empty. A rigid clause tail binds R's tail (the clause-tail pass, §3.5).
- Own-abort constraint: a `Fail` label or a rigid tail in a clause row
  imposes M ⊑ m, so m cannot be N.
- Requirement marks flow by consumption: R ⊑ c for each clause row c.

**`with h { body }`**, with `h : Handler(m L with R)`, under current row ρ:
- R is consumed into ρ as a restricted row (§3.5). It is no longer
  unified with ρ. That keeps R the clause effects, not the context's
  effects; it accepts at least what equality accepted.
- The body checks against `f L + ρ`, where f is a fresh *frame mark* for
  this installation. Constraints:
  - m ⊑ f (an own-abort-capable handler gives an M frame);
  - for each label of R resolved at settling, the mark of the ρ
    occurrence it was matched with ⊑ f (the clauses reach those outer
    frames);
  - if R's resolved tail is rigid ϱ, then M ⊑ f, and ρ must end in ϱ
    (§3.5 tail pass).
- So the same handler value can give an N frame in one installation and
  an M frame in another (review I1, second program). A forwarding helper
  needs no mark variable (review I2).

**`defer e`.** The existing rules stand: an own row, and E_EFFECT for a
`Fail` label or a rigid tail. In addition, every non-`Fail` label of the
resolved own row d imposes d ⊑ N.

**Entry.** No change.

### 3.5 Settling

The order follows Check.purs:116-121, with steps 2, 4, 5 and 6 new.
*Restricted rows* are deferred own rows (target: the current row at the
`defer`), clause own rows (target: their handler's R), and each
installation's R (target: the installation's ρ). One handler can thus be
several restricted entries.

1–3. **Settle keys and consume late labels, as one loop** (revision 5;
   in revision 6 it also covers each installation's R).
   This is the corrected procedure of the focused termination review,
   review-fx008-termination-result.md. It replaces revision 4, which
   failed P3 and P4, could hang (rule (c) on duplicates), and dropped
   clause rows' rigid tails (T1). Each round:
   - (a) Run `settleKeys`. Deferred `Fail` keys settled here may add
     labels to restricted rows, clause rows included.
   - (b) Resolve every restricted row X_i and its target T_i. Build the
     **feed graph**: an edge i → j when T_i's and X_j's tails resolve to
     the same unbound meta, compared as metas. Fix the round's order: a
     topological order of the graph's strongly connected components, with
     source position inside and between them.
   - (c) For each key κ, let w_i(κ) = count_κ(X_i) − count_κ(T_i). Leave
     out `Fail` keys for deferred rows. If some cycle (self-loops
     included) has Σ w_i(κ) > 0, report the existing side-condition error
     (`… cannot be made equal: both end in …`). Report it at that cycle's
     earliest row with w_i(κ) > 0. Such a cycle has no finite solution,
     and its sum never changes under later bindings. Cycles whose sum is
     at most 0 for every key are allowed. The count must be per key: a
     test of key presence alone hangs on duplicates (review dup.wxw).
   - (d) In that order, consume each row's resolved labels into its
     target, with a fresh tail, directionally (§3.4: target ⊑ row on
     matched pairs; copies at tail binding). Clause rows and installed R
     keep `Fail`; deferred rows leave it out, as today.
   - **Exit** after a round in which (a) decided no pair and no restricted
     row's resolved label count changed, whatever binding caused the
     change. Argument-level row bindings count: a late label's argument
     can bind a clause row's tail (review argbind.wxw).
   - **On exit**, a deferred-key pair still set aside is E_TYPE `Fail
     needs a concrete error family`. Then run the clause-tail pass.
   - **Tail pass (review T1; revision 6 generalizes it).** A clause row
     whose resolved tail is a rigid ϱ (for example, a clause calling an
     ambient-row callback) needs R to end in ϱ. In turn, an installed R
     whose tail is ϱ needs its installation's ρ to end in ϱ.
     - Bind R's unbound tail meta to ϱ. If R is closed, or ends in another
       variable, report the missing-capability error.
     - Repeat while that gives another clause row a rigid tail. Each
       repetition binds a distinct meta.
     - This pass runs after the loop, never inside it, so acceptance does
       not depend on order.
     - It adds no labels, so it cannot reopen the loop.
     - Today the rule holds automatically, because clauses check against
       R. Without the pass, the base effect system is unsound (the
       review's rigid.wxw is rejected today).

   Properties (the user's conditions, established by the focused review
   with this correction; argument in the review file):
   1. **Occurrence and multiplicity.** Rows grow only at their tails, and
      keys are fixed after the first round. So the r-th occurrence of a key
      in a restricted row always pairs with the r-th occurrence in its
      target. Re-consuming the whole row is required: consuming only new
      labels would pair a late duplicate with the wrong frame. No
      provenance is read (spec §6).
   2. **Repeated arrivals constrain.** Every round re-unifies every pair.
      Old pairs are no-ops; new pairs are imposed.
   3. **No early stop.** The exit test counts every source of new labels:
      settled keys, feed-edge extensions, and argument-level bindings.
   4. **Termination and order.**
      - No step creates a new row-meta class. Each argument-level change
        to the graph merges, closes or rigidifies a class, so there are at
        most N0 + 1 epochs, where N0 is the initial number of classes.
      - Within an epoch, propagation is Bellman-Ford relaxation. So the
        loop runs at most (N0 + 1)(2n + 1) + 1 rounds, for n restricted
        rows, plus the pairs that (a) decides.
      - With no feed edges the loop takes two rounds, so linearity is
        unaffected.
      - The procedure accepts exactly when the containments and
        equalities have a finite solution, which does not depend on
        order.
      - Sibling tie-breaks give the same equation set in every order;
        for example `State(Int)` and `State(Bool)` reaching one tail from
        two feeders mismatch in both orders, and only the headline
        differs.

   **Fallback, disqualified.** The fallback is never to extend a tail that
   ends any restricted row. It rejects four programs that are accepted
   today and that the corrected procedure accepts (review f1-f3,
   cycle2open):
   - a defer inside a clause;
   - a clause inside a defer;
   - a program with no `defer` at all (C2's late `Fail` inside an outer
     clause), which breaks the success criterion that programs without
     `defer` keep their acceptance;
   - a satisfiable two-row cycle.

   It is recorded only so that it is not chosen silently.

4. **Defer judgement**, as today, after late consumption: a `Fail` label
   or a rigid tail is E_EFFECT.
5. **Mark check.** The constraints form a graph whose nodes are mark
   metas plus *atoms*: N, M, and the declaration's own rigid mark
   variables. Its edges are x ⊑ y, with equalities as two edges.
   - The constraints are satisfiable for every value of the mark
     variables exactly when no path runs from atom a to atom b with
     a ≠ b, where a is not N and b is not M. The forbidden paths are
     M→N, M→k, k→N and k→k′; for two-point inequalities, path
     reachability is the whole story.
   - The algorithm propagates, for each node, the set of atoms that reach
     it (at most |variables| + 2 per node, so O(edges × atoms)). It then
     checks every edge into an atom.
   - Each node records its first incoming edge, so a violating path is
     reported with its sources (§3.6).
6. **Close** every remaining mark meta to M (they are erased).
7. The comparable and printable checks, then the entry check (for
   `main`), unchanged.

### 3.6 Diagnostics (spec §6 style; exact texts in the plan)

A violating path gives the headline by where it ends:
- At a `defer` demand: `defer must not fail, but it performs Log, whose
  handler may fail`.
- At a `nofail` assumption of a call: `Expected nofail Log, found Log`.
- At a frame whose handler can abort: `This handler may fail here: its
  clause for log fails with E` / `… performs Log, whose handler may fail`
  / `… may perform any effect of <r>`.
- At a rigid mark variable: `… performs nofail(k) Log, whose handler is
  fail-free only when the caller's is`.

The primary span is the demand in the rejecting declaration's body. Notes
follow the path back to its source: a signature's written `with` (with
the hint `write with nofail Log`), the failing clause, the installation,
and the outer handler. Hops are bounded like Task 9 path hops. Existing
texts stay; some exact texts of rejections without `defer` may move
(§6). Provenance never influences typing.

## 4. Interactions

**4.1 Row erasure.** Marks never reach Domain.IR (§3.3). Go output, `ctx`
mode, finiteness and the snapshots are unchanged.

**4.2 Scoped labels.**
- Marks belong to occurrences and follow first-occurrence matching. Copies
  keep position and multiplicity.
- Key definition and the side condition are unchanged.
- The unifier properties gain marks and directional pairs.

**4.3 Handler types.** `Handler(m L with R)`: m is own-abort freedom and R
is the clause effects with their assumptions. An N handler type promises
no escaping `fail` and no unknown calls; installations add the outer
frames.
- The change from unifying R with ρ to consuming it accepts strictly
  more. A handler value installed under two different rows no longer
  forces those rows equal.
- Handler values stay neither comparable nor printable.

**4.4 CF001 R0 (D4, applied with the spec amendment).**
- R0's "performs no X" becomes a per-label predicate plus the rigid-tail
  rule. For `defer`: not `Fail`, and marked N. For a `par` child: is
  `Fail` (a child performs no operation that reaches a parent frame).
- Long-lived boundaries (O-2: services, escaping callbacks) become
  *abort-free*: no `Fail`, every label N, no rigid tail.
- Text changes go to CF001 §5 R0, decision O-2 and the §8A
  escaping-callback row.

**4.5 FX007 (D5).** It is re-scoped to `nofail ...e`: a written row
variable whose instances are abort-free, carried on row metas and checked
at instantiation. It is deferred.

**4.6 General resume (FX006).** Any `ctl` clause makes its handler's own
mark M until that milestone proves a finer rule.

**4.7 Cleanup context.** Deferred labels are consumed into the
registration row. Their marks bound the frames that will run them.

**4.8 Provenance and oracle.**
- Edges reuse occurrence links for notes, and copies link to their
  originals. Provenance never decides typing.
- The oracle's parser accepts `nofail` and `nofail(k)` and ignores them.

## 5. Soundness argument (a proof obligation)

Claim: in a well-typed program no deferred expression ends in a typed
abort.

Satisfiability (§3.5 step 5) quantifies over all values of the mark
variables. So it is enough to argue for one instantiation, with every
mark a constant.

1. **Frames are honest.** Take the frame installed by `with h` with frame
   mark f = N.
   - Then m ⊑ f gives m = N: by the own-abort constraint, no clause row
     has `Fail` or a rigid tail, so a `fail` in a clause is handled inside
     it.
   - Every label the clauses perform is in R, by the restricted-row
     consumption, late labels included. Its outer occurrence in ρ has
     mark ⊑ f = N.
   - By induction on evaluation, those outer frames cannot abort.
   - So no clause run by this frame ends in an abort.
   - Handler values reach installations only by type equality, or by
     opening at weakening positions. So m is honest wherever it is
     installed.
2. **Assumptions are met.** Each consumption imposes frame ⊑ assumption
   (directional), and copies made at tail binding inherit that edge. So a
   computation that assumes N for κ runs under an N frame:
   - a call or lambda application consumes;
   - a clause runs in its installation's outer context, which its R
     occurrence was consumed into;
   - cleanup runs in its registration context.
3. **Mark variables.** A rigid k is an atom that may be either value, so
   any path that relies on k being N, or on k being M, is rejected.
   Instantiation gives fresh metas per use.
4. **`defer e`.** The own row has no `Fail` and no rigid tail (step 4),
   and d ⊑ N for every label (step 5).
   - By 2 and 1, no operation `e` performs ends in an abort.
   - Failures of handlers installed inside `e` appear in `e`'s own row as
     `Fail`, so they are rejected or handled.
   - So `e` ends normally, ends by a defect, or diverges.

Earlier reviews probed handler values in parameters, results, fields and
data; opening and variance; escaping lambdas; ambient and named rows;
nested and forwarding handlers; `handle` and handlers inside cleanup;
staging; recursion; and deferred keys. Revision 6 changes the `with` and
consumption rules, so those probes must be re-run against it.

## 6. Compatibility

Newly rejected. Each case depends on a handler that may fail:
- A `defer` of an operation of a signature label written without
  `nofail`. One existing test pins this as accepted:
  test/fx-cleanup-programs.mjs `a defer performing a non-Fail effect`. It
  migrates to `with nofail Log` with the same output.
- The pinned oracle program and the §1 cross-function form.
- A `defer` reaching a frame whose handler fails, or whose clause reaches
  a failing outer handler.
- A `defer` reaching a frame whose handler calls a callback with an
  unknown row (the clause or R has a rigid tail).
- **`nofail` assumptions spread up call chains**, to the declaration that
  installs the handler. `nofail(k)` lets wrappers pass the assumption
  through without fixing it.
- A late-label system with no finite solution (review N1 and dup.wxw,
  both accepted today with a spurious label): the side-condition error.

No longer rejected in revision 6:
- Review I1's two programs (a local lambda, and a let-bound handler, each
  used under a fail-free and a failing handler).
- I2's forwarding helper.
- N5's `run`.
- Revision 5 rejected all of these.

Unchanged:
- programs without `defer` keep their acceptance, or gain acceptance
  where `with` used to force rows equal;
- run-time behaviour.

Some exact diagnostic texts without `defer` may move, because clause and
installation rows are now separate; affected tests are updated with the
reason recorded.

## 7. Limitations (proposed, recorded)

- **L1.** Marks nested inside data, fields or a callback's parameters are
  not opened at declaration use. Locals are not opened. Directional
  consumption removes most practical cases.
- **L2.** Callback rows in parameters are never opened. A rejection there
  is sound.
- **L3.** Bracket-style cleanup through `...e` stays rejected until FX007.
- **L4 (residual).** Copies are made when a tail is bound. Labels that
  later reach a *shared* tail are shared by identity, so their marks are
  equal. This is sound but less precise. Example to pin: the plan must
  produce one, or show that none is reachable.
- **L6.** Mark variables are not allowed in `type` or `effect`
  declarations. Row arguments carry marks inside rows.

L5 (no mark polymorphism) is resolved by per-installation frames and
`nofail(k)`.

## 8. Proposed spec text (applied on approval, with D4's CF001 text)

- **§1:** `nofail` is contextual; `nofail(k)` is a mark variable.
- **§2:**
  - A new paragraph "Marks" condensing §3.1-§3.4.
  - "Consumption and opening": directional pairs, copies at tail binding,
    and handler-type opening only.
  - `handler` rule: `Handler(m L with R)`, own rows, exact R, own-abort
    constraint.
  - `with` rule: R consumed, not unified; frame mark f and its
    constraints.
  - `defer` rule: append "every other label it performs must be marked
    `nofail` …", with the E_EFFECT text.
- **§3 "Cleanup failures":** after "an open row tail", add "or perform an
  operation whose frame may fail (FX008)". §3 "Clause context" is
  unchanged.
- **§5:** probe 6 and the regression proofs gain §9's cases.
- **§6:** the new headline kinds.

## 9. Verification (for the plan)

Rejections, each asserted with exact text, primary span and notes:
- the pinned program and the §1 cross-function form;
- a `Handler(nofail Log)` parameter given a failing handler;
- `mk(): Handler(nofail Log) = handler Log { log(n) => fail(E) }`;
- a `nofail` call under an M signature;
- a frame whose handler's clause logs to a failing outer handler, under a
  `defer`;
- a handler calling an ambient callback, under a `defer`;
- `nofail Fail(E)`;
- a rigid `nofail(k)` demanded N;
- review C2's late `Fail` and T1's rigid tail (both still rejected);
- review dup and n1 (side-condition error, under a timeout).

Acceptances, with run output:
- an N signature under a fail-free handler;
- I1's two programs; I2's three uses of `prefix`; N5's `run`;
- `around` (§3.2) under a fail-free and under a failing outer handler,
  the former with a `defer` in `body`;
- one handler value installed under two different rows;
- cycle2open, f1, f2, f3 and argbind;
- Console cleanup;
- the migrated fx-cleanup program.

Other checks:
- unifier properties with marks and directional pairs;
- linearity: 8,000 defers and 1,000 nested handlers;
- the path check with many mark variables.

Isolated regression mutants, each caught:
- equality instead of directional pairs (I1 fails);
- no copies at tail binding (the I1 lambda fails);
- R unified with ρ at `with` (the two-row install fails);
- per-installation frame replaced by m (I2 fails);
- m ⊑ f dropped (a failing handler under a `defer` is accepted);
- outer-occurrence ⊑ f dropped (a forwarding clause into a failing outer
  handler is accepted);
- rigid variables treated as N (unsound acceptance);
- the rev 5 settling mutants (cycle weight, exit test, clause-tail pass).

Differential testing:
- the one-way soundness differential (compiler acceptance implies the
  oracle never reports `typed abort escaped cleanup`), plus the default
  corpus with failing random clauses, 0 differences.

## 10. Implementation outline and cost (not authorized)

| Module | Change |
|---|---|
| Domain.Row | mark field |
| Parse, Resolve | `nofail`, `nofail(k)`, mark-variable sort, Console normalized |
| Unify, UnifyRow | mark equality in types; directional pairs and copies when consuming |
| Consume | directional consumption |
| Use, Stages | instantiation of mark variables, handler-type opening |
| Handler | clause own rows; `with` consumes R; frame marks |
| Defer and a new Settle module | the rev 5 loop over all restricted rows, tail pass |
| Features.Check.Mark (new) | the edge graph and the path check |
| DeferNotes, RowName, Domain.Problem, Format.Diagnostic | notes, printing, kinds |
| Check-to-IR boundary | strip marks |
| oracle parser, generators, tests | — |

`Label` has about 100 sites in about 20 modules. Expect roughly twice
Task 8 and its fix round. Plan it in several tasks:
1. representation and syntax;
2. directional consumption and copies;
3. restricted-row settling;
4. handlers and `with`;
5. the mark check and diagnostics;
6. migration and differential.

FX001 Tasks 11-12 follow, and Task 12's ADR 010 records the rule.
On approval, Task 11 Step 1 is amended:
- `nofail` along every cleanup call chain;
- real and fake handlers selected by `if`/`match` share one mark, so each
  handler that a cleanup reaches is fail-free in both forms, or handles
  its failures inside its clauses;
- no callbacks in clauses on cleanup paths;

The dropped-handler diagnostic and the key-count baseline are
unaffected.


## 11. User decisions (2026-10-10, interview)

- D0: yes. Effectful cleanup stays allowed when its handler cannot fail.
  Programs that relied on an unknown handler become errors.
- D1: a mark per label occurrence (approach A).
- D2: `nofail`, contextual. It means no escaping typed abort; defects
  and divergence remain possible.
- D3: all three opening positions (§3.4).
- D4: CF001 changes to "abort-free" now, in the same change as the spec
  amendment.
- D5: FX007 is re-scoped to written abort-free row constraints
  (`nofail ...e`). Implementation is deferred.
- D6: mark variables are **included in FX008**, spelled `nofail(k) L`.
- D7: directional checking is **included in FX008**.
- Process: revision 6 covers D0-D7 and the spec §2/§3 text. One Opus
  review follows, including a second check of the revision 5 settling
  procedure. Then the user approves the written spec.
- FX009 is fixed now, separately and test-first, in parallel.

## 12. Outside advice (2026-10-10; not the user's decisions)

The user shared outside advice and asked that it be treated as advice
only. The user later decided D0-D7 (§11). The advice's technical points:

- **Recommendations:** D0 yes; D1 marks per occurrence; D2 `nofail`,
  defined narrowly (no escaping typed abort; defects and divergence still
  possible); D3 yes, with the opening rules reviewed carefully at callback
  positions; D4 "abort-free" now; D5 re-scope FX007 around abort-free row
  constraints; D6 a near-term follow-up, before reusable handler libraries
  are treated as supported; D7 a follow-up with concrete acceptance
  examples pinned now.
- **Task 11 is not evidence of adequacy.** That Task 11 works with inline
  handlers is delivery evidence, not evidence that the abstraction is
  satisfactory. D6 and D7 affect ordinary composition: forwarding helpers,
  and one value reused under different handlers. Writing a relationship
  once in a type is close to the language's purpose, so duplication must
  not become the long-term design. D6 and D7 stay visible as
  composability work and are not closed by Task 11.
- **The callback rule is conservative.** Rejecting callbacks whose
  ambient rows are unconstrained is defensible. A future design should
  accept callbacks whose rows establish abort freedom explicitly (the
  `nofail ...e` direction, §4.5).
- **Termination must be established, not assumed:** occurrence and
  multiplicity preserved; repeated arrivals constrain; no early stop while
  substitutions create obligations; indirect cycles terminate; acceptance
  independent of order. These are the required properties of §3.5 steps
  1-3, under focused review.
- **The fallback is a separate precision trade-off.** It may not be
  chosen silently during implementation; its extra rejections need
  concrete examples and review (§3.5).
- **Scope of the guarantee.** Erasing marks before specialization gives a
  static guarantee without runtime machinery. It does not establish race
  freedom, determinism or safe resource sharing, which remain separate
  concurrency obligations (CF001).
- **What verify shows.** The green verifies show that the documentation
  changes preserve the existing compiler. They do not validate the
  proposed checker.
