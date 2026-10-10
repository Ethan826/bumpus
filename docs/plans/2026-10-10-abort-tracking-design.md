# Tracking handlers that may fail: design (FX008)

Status: design note. Revision 1 (2026-10-10) applies the independent Opus
review (docs/sdd/2026-10-09-effects-plan/review-fx008-design-result.md:
Accept with fixes, C1-C2, I1-I4, M1-M10). Revision 2 applies the scoped
re-review (rereview-fx008-design-result.md: C1, C2, I3, I4 and M1-M10
addressed; I1 and I2 partly; new N1 non-termination, Critical, and
N2-N5). Round 3 (N1 only) found the shared-suffix rule sound but the
measure unsound as written, because it relied on provenance links.
Revision 4 replaced the late-consumption step (§3.5 steps 1-3) after
the user shared outside advice (§12). A focused termination review
(review-fx008-termination-result.md) refuted P3 and P4 as written and
found T1 (clause rigid tails dropped, Critical). Revision 5 adopts its
corrected procedure. That procedure is the reviewer's own and has not
been checked by a second party. The note is awaiting the
user's decision and is not approved; nothing here is implemented. It will
amend the effects spec (docs/plans/2026-10-09-effects-design.md) §2 and §3
once the user decides. Context: BACKLOG FX008 and FX007; CF001 R0
(docs/plans/2026-10-09-concurrency-foundations-design.md §5).

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
What A lacks is mark polymorphism (§7 L5, D6), not a different approach.

## 3. Design (approach A)

### 3.1 Meaning and invariant

A mark is attached to each non-`Fail` label occurrence. It is `nofail` (N)
or may-fail (M, written as a plain label).

Invariant: suppose an expression is checked with current row ρ, and the
k-th occurrence of key κ in ρ is marked N. Then whenever the expression
runs, the k-th handler frame for κ in its dynamic context cannot end an
operation in a typed abort. That is an abort escaping the clause; a
clause may fail and handle that failure inside itself. Defects and
divergence remain possible everywhere (spec §1: `with pure` promises
neither).

The invariant covers every occurrence, not only the first, because
clauses run in outer contexts and so reach frames below the innermost
one.

### 3.2 Syntax

`nofail` is contextual, like `pure`. It is recognized directly before a
label in a row: after `with`, after `+`, at the start of a row argument,
and as the handled label of `Handler(…)`. Elsewhere it is an ordinary
name.

```
fn work(): Unit with nofail Log = { defer log(1); () };
fn run(h: Handler(nofail Log with Console)): Unit with Console =
  with h { work() };
Job(Int, nofail Log + Clock)                               // row argument
```

Special cases:
- `nofail Fail(E)` is E_TYPE: a failure always aborts.
- `nofail Console` is accepted as redundant.
- `nofail ...e` and `nofail ...` are E_SYNTAX, reserved for FX007 (§4.5).
- A written `Handler(nofail Log with Fail(E))` is accepted. Its R is
  merely wider than any fail-free handler can use, which is sound.

Row display prints `nofail L` for N. M labels, and unsolved marks, print
as plain `L`.

### 3.3 Representation and conventions

- `Label EffectRef (Array t)` gains a mark: N, M, or a mark meta.
- Mark metas live in the checker substitution beside type and row metas.
  `resolvedRow` resolves them.
- Signatures contain only the constants N and M. No mark is quantified
  (D6 would add mark variables).
- Console labels are normalized to N at resolution, including the label
  `print` consumes. Otherwise every `with Console` program would mismatch.
- `Fail` labels carry a fixed placeholder that is never compared.
- Label keys are unchanged.
- Marks are stripped at the Check-to-IR boundary. That covers row
  structure, which is erased already, and the handled label inside
  `THandler`, which is part of a type. Without stripping, specialization
  keys (derived `Ord`) would split `Handler(nofail Log)` from
  `Handler(Log)`. Instantiation's `admissible` (ADR 007) ignores marks.

### 3.4 Typing rules (changes to spec §2)

**Written labels.** A written label is M unless it is written `nofail`.
Console is the exception (§3.3). This covers own rows, parameter rows,
field rows, row arguments and `Handler(L …)`.

**Matching.** Scoped-label unification matches a label against the first
occurrence with the same key. At that point it unifies the two marks, as
it unifies their arguments. A mismatch is the same-key kind (spec §6),
with headline `Expected nofail Log, found Log`. Duplicates keep their own
marks.

**Opening (spec §2 "Consumption and opening").** Opening happens only when
a declaration reference is used (Features.Check.Use `declarationUse`,
Stages `openedRow`). It replaces a mark with a fresh meta only where that
weakens what the declaration needs or gives:
1. An M label in the declaration's own final-stage row. The callee relies
   on nothing, which mirrors opening a closed row.
2. An M handled label in a top-level parameter type (`h: Handler(Log …)`).
   The callee assumes the handler may fail.
3. An N handled label in the top-level result type. The value cannot fail,
   so callers may use it as either. This matters mostly where an `if` or
   `match` joins it with M-typed values.

Never opened:
- N in own rows. It is a requirement.
- Any mark inside a parameter's *row*. In `f: Int -> Int with Log` the
  callee runs `f` in its own context, which may fail, so opening would be
  unsound.
- Locals.

An operation reference's own label gets a fresh mark meta.

**`handler L { clauses }`.** Its type is `Handler(m L with R)`, with m a
fresh mark meta.
- Each clause is checked against a row of its own. That row's tail is
  never unified with R; its labels are consumed into R. This is the R0
  technique. Without it, R's unification with each installation row would
  blur what the clauses themselves perform.
- Labels that reach a clause row later (through a shared meta, such as a
  callback's row fixed after the handler expression) are consumed into R
  at settling, keeping `Fail` (§3.5 steps 1-3). Today they reach R
  automatically, because clauses check against R itself
  (Handler.purs:38,71). Without late consumption the base effect system
  would become unsound (review C2).
- At settling, each clause's resolved own row contributes:
  - for each non-`Fail` label ℓ, an edge mark(ℓ) ⊑ m, where N ⊑ M (if m
    is N, ℓ must be N);
  - a `Fail` label, or a tail resolved to a rigid row variable, blocks m
    from being N.

**`with h { body }`**, with `h : Handler(m L with R)`. The body checks
against `m L + ρ`. R unifies with ρ as today, marks included.

**`defer e`.** The existing rules stand: an own row, and E_EFFECT for a
`Fail` label or a rigid tail. In addition, every non-`Fail` label of the
resolved own row is demanded N at settling.

**Lambdas, `let`, partial application, function values, data.** No new
rule. Marks travel inside rows and unify wherever rows do. A local lambda
or handler used in two handler contexts therefore makes their marks equal
(§7 L4).

**Entry.** No change; Console is N.

### 3.5 Settling

Today a declaration ends with `settleKeys`, `settleDeferred`, `settleKeys`
again, then the comparable and printable checks, then the entry check
(src/Features/Check.purs:116-121). The new order uses one list of
restricted rows (deferred own rows and clause own rows); steps 2, 4 and 5
are new (review C2, N2):

1–3. **Settle keys and consume late labels, as one loop** (revision 5).
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
     target, with a fresh tail. Clause rows keep `Fail`; deferred rows
     leave it out, as today.
   - **Exit** after a round in which (a) decided no pair and no restricted
     row's resolved label count changed, whatever binding caused the
     change. Argument-level row bindings count: a late label's argument
     can bind a clause row's tail (review argbind.wxw).
   - **On exit**, a deferred-key pair still set aside is E_TYPE `Fail
     needs a concrete error family`. Then run the clause-tail pass.
   - **Clause-tail pass (review T1).** A clause row whose resolved tail is
     a rigid ϱ (for example, a clause calling an ambient-row callback)
     needs R to end in ϱ.
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
4. **Defer judgement**, as today: a `Fail` label, or a rigid tail, is
   E_EFFECT. This judgement moves from before late consumption
   (Defer.purs:102-103) to after it. That is needed for C2, and it can
   only add rejections.
5. **Mark solve.**
   - Seeds: every mark that resolves to N from any source, and the demands
     from deferred rows. Sources include signature constants, `nofail`
     parameters, results and fields, N labels in R, and an N mark reached
     by unification.
   - Each mark meta records the first source that made it N, for
     diagnostics.
   - A worklist propagates seeds. A meta demanded N is bound to N, and an
     M constant demanded N is an error. When a handler mark is N, its
     blocks are errors and its edges demand N.
   - Each mark becomes N at most once, so the solve is linear.
6. **Close unsolved mark metas to M.** This happens after the solve and
   before `settle`/`holes`, which never treat mark metas as type holes or
   renumber them.
7. The comparable and printable checks, then the entry check (for
   `main`), unchanged.

Closing unsolved mark metas to M is harmless because every
value that leaves a declaration passes through signature types, whose
marks are constants. A mark meta has no meaning outside its declaration.
This is the same escape argument the rigid-tail rule relies on.

The solve is local to one declaration: no scheme carries a constraint,
unlike FX007's lacks-`Fail` proposal. Inequality avoids spurious errors
*only* on the clause-to-handler edge. Unifying that edge would force an
outer handler to M whenever a failing inner handler logs to it. Every
other mark relation is equality (§7 L4).

### 3.6 Diagnostics (spec §6 style; exact texts in the plan)

Primary span: the demand or seed source in the rejecting declaration. That
is the `defer` item, the call or annotation that made the handler's mark
N, or the call whose N label met an M constant.

Notes:
- the signature boundary, at the written `with`: "Log may be handled by a
  caller's handler that fails; write with nofail Log";
- the lexical handler's failing clause, or the clause's operation whose
  own handler may fail, with hops between handlers bounded like Task 9
  path hops;
- the origin operation;
- for an equality merge (§7 L4), "this function value is also used under
  the handler at …".

Headlines:
- `defer must not fail, but it performs Log, whose handler may fail`;
- `Expected nofail Log, found Log`;
- `This handler must not fail, but its clause for log fails with E`,
  `… performs Log, whose handler may fail`, or `… may perform any effect of
  <r>`.

Existing texts stay, but some may move (§6). Provenance never influences
typing.

## 4. Interactions

**4.1 Row erasure (spec §4).** Marks never reach Domain.IR (§3.3), and
they create no key, layout or dependency. Go output, `ctx` mode and the
snapshots are unchanged. Finiteness rules A and B are untouched.

**4.2 Scoped labels.**
- Marks belong to occurrences and follow first-occurrence matching. In
  `with tH { with aH { log(1) } }`, the body sees `aH`'s mark.
- Key definition and the Leijen side condition are unchanged.
- The unifier property generators (spec §5) gain marks. Equivalence
  includes marks.

**4.3 Handler types `Handler(L with R)`.**
- The mark describes the handler and is written on its label.
- An N handler's clauses perform only N labels. So the honest type of a
  fail-free forwarding handler is `Handler(nofail Log with nofail Log)`.
  `Handler(nofail Log with Log)` is accepted, but no clause that logs can
  satisfy it.
- Handler values stay neither comparable nor printable.
- Clause own rows change what Check knows, not what R means.

**4.4 CF001 R0.** R0's "performs no X" becomes a predicate on each label
of the restricted row's own row, plus the rigid-tail rule:
- For `defer`, the predicate becomes "not `Fail`, and marked N"; it was
  "not `Fail`".
- For a `par` child, "is `Fail`" is unchanged: a child performs no
  operation that reaches a parent frame, so marks do not matter. A child
  may handle its own operations internally.
- CF001 calls long-lived boundaries (O-2: services, escaping callbacks)
  "Fail-free". They must be "abort-free": no `Fail`, all labels N, no
  rigid tail. Otherwise the FX008 hole reappears across goroutines.
- Proposed CF001 wording changes (D4): §5 R0, decision O-2, and the §8A
  escaping-callback row.

**4.5 FX007.** The bracket idiom needs a row variable whose instances are
abort-free. That would be written `nofail ...e`. It would be carried as a
constraint on row metas through tail unification inside a declaration,
and checked at each instantiation. It stays local and written, instead of
FX007's inferred qualified schemes. It is out of FX008's scope; FX007
stays open and is re-scoped (D5).

**4.6 General resume (FX006).** The mark means "the handler may unwind
past the operation". Any `ctl` clause makes its handler M until the
general-resume milestone proves a finer rule. Whether a clause resumes is
not decidable in general: it may resume and then fail, or drop the
continuation conditionally. So `defer` stays sound once continuations can
be dropped.

**4.7 Cleanup context (spec §3).** Deferred labels are consumed into the
registration row, with marks unified. So a deferred label's static mark
describes the frame that will run it.

**4.8 Task 9 provenance; oracle.** Mark seeds and demands reuse the
occurrence links (Provenance) for notes. The oracle's runtime model is
unchanged. Its parser accepts `nofail` and ignores it.

## 5. Soundness argument (a proof obligation)

Claim: in a well-typed program no deferred expression ends in a typed
abort.

Honesty comes from the solve, not from unification. During checking an N
constant may meet a meta that is later blocked; the solve (§3.5 step 5,
seeded from *every* N) rejects that. After settling, every unified pair
of marks is equal, and every N handler mark satisfies its blocks and
edges.

1. **The invariant (§3.1), by induction on evaluation.**
   - `with h` pushes a frame whose handler has `h`'s static mark. That is
     the mark of the body's first occurrence of L, and the other
     occurrences shift by one, matching the frames.
   - A call unifies the callee's own-row labels with the caller's. After
     solving, an N callee label equals the caller's mark, which is N.
     Opened M labels impose nothing, and a callee checked with M assumes
     nothing.
   - A lambda's row unifies with the current row at each call.
   - A clause runs in its `with`'s outer context. Its own row's labels
     reach R, including late labels (§3.5 steps 1-3), and R unifies with that
     context's row. So the clause's operation marks describe the outer
     frames.
   - Values leave a declaration only through signature types, whose marks
     are constants, so closing local metas to M changes no other
     declaration.
2. **Handler marks are honest.** If m is N, then after the solve every
   label of every clause's own row is N, and no clause row has `Fail` or a
   rigid tail.
   - By 1, each operation a clause performs reaches a frame that cannot
     abort.
   - A `fail` in a clause is handled inside the clause, since its `Fail`
     is absent from the clause's own row and an abort targets the
     innermost `handle` for its key.
   - Handler values reach an installation only through unification (equal
     marks) or opening, which happens only at weakening positions.
3. **`defer e`.** After §3.5 step 4, the own row has no `Fail` and no
   rigid tail, and after step 5 every label is N.
   - By 1 and 2, no operation `e` performs ends in an abort.
   - A `fail` inside `e` is handled inside `e`.
   - A handler installed inside `e` has its clause row consumed into `e`'s
     own row, so its failures appear there as `Fail` and are rejected or
     handled.
   - So `e` ends normally, ends by a defect, or diverges. These are the
     cases spec §3 leaves.

The reviewer probed handler values in parameters, results, fields and
row-parameterized data; opening positions 1-3 and their variance;
escaping lambdas; ambient and named rows; nested and forwarding handlers;
`handle` and handlers inside cleanup; staged and partial application;
recursion; and deferred keys. Beyond C1 and C2, now fixed, none produced
an unsound acceptance.

## 6. Compatibility

Newly rejected. Each case depends on a handler whose failure is unknown
or possible, except the last two, which are imprecision:
- A `defer` of an operation of a signature label written without
  `nofail`. One existing test pins this as accepted:
  test/fx-cleanup-programs.mjs `a defer performing a non-Fail effect`. It
  migrates to `with nofail Log` with the same output.
- The pinned oracle program, and the §1 cross-function form.
- A `defer` of a label of a lexical handler whose clause fails.
- **`nofail` spreads up the call chain.** A caller written `with Log` that
  calls a `nofail Log` function mismatches, so every declaration between
  the cleanup and the installing declaration writes `nofail`. This affects
  Task 11's scenario.
- **A handler whose clause calls any callback, or calls a local lambda
  whose row ends in the declaration's ambient row, can never be N.** Its
  clause row has a rigid tail. So cleanup cannot perform that handler's
  label.
- **Equality merges (§7 L4).** A local lambda or let-bound handler used
  both under a fail-free handler (with a `defer`) and under a failing
  one. Two such programs are accepted today and run correctly (review I1:
  `2 1 9`, `11 9`).
- **One forwarding helper used both ways (§7 L5).** Accepted today and
  prints `101 101 0 9` (review I2).
- **A handler parameter with an M clause row, installed under a `nofail`
  own row** (§7 L5, review N5). For example, `fn run(h: Handler(Log with
  Log + ...e)): Unit with nofail Log + ...e = with h { … }`: R's M `Log`
  mismatches the own row's N `Log`. That is sound behaviour, but R's
  invariance rejects it.
- **A restricted row whose late labels have no finite solution**
  (§3.5 steps 1-3, step (c)). For example, review dup.wxw, accepted
  today, whose defer row ends up `[Console, Log, Log] + τ` against
  `[Log, Console] + τ`. It becomes the side-condition error. Today a
  single pass adds a spurious label and stops.
- **A restricted row sharing its tail with its target** (§3.5 steps 1-3,
  review N1). For example, a never-called lambda with `let k = fn(n: Int)
  => print(n); defer k(1); with handler Log { … } { k(2) }`. It is
  accepted today with a spurious `Log`. It becomes the existing
  side-condition error at the `defer`, because the monomorphic `k` is
  typed as performing `Log`. The no-`defer` form (a clause and the body
  both calling one local lambda) stays rejected with today's
  side-condition error; without the cycle-weight rule it would hang.

Unchanged:
- programs without `defer` (acceptance and meaning);
- `defer` of Console, `crash`, pure code or self-handled failures;
- `defer` of operations under fail-free lexical handlers, except for
  equality merges (§7 L4);
- all run-time behaviour.

Diagnostics may move. Separate clause rows change the exact text of some
rejections without `defer`. One example is a clause calling a local lambda
that the body also uses, today `Console + ... and Log + Console + ...
cannot be made equal`. Acceptance is unchanged, and affected exact-text
tests are updated with the reason recorded.

## 7. Limitations (proposed, recorded)

- **L1. Nested positions are not opened.** Marks inside data, fields, or
  a callback's parameters are not opened at declaration use. Locals are
  never opened. Workaround: use a declaration, since top-level positions
  are opened.
- **L2. Callback rows in parameters are never opened.** A named `nofail`
  function cannot be passed where `with Log` is written. This rejection
  is sound, because the callee may run the function under a failing
  handler.
- **L3. Bracket-style cleanup through `...e` stays rejected** until FX007
  (§4.5).
- **L4. Marks unify everywhere except the clause-to-handler edge.**
  - So a monomorphic local used under two handlers identifies their marks
    (review I1).
  - Workaround for a lambda: a declaration, which is opened per use. For
    a let-bound handler, write the handler inline at each use; a
    declaration gives it a constant mark and runs into L5 (review N3).
  - Directional consumption (current ⊑ stage, ρ ⊑ R) would fix this, but
    binding a stage row's tail shares labels by identity. So it would also
    need fresh mark copies and edges on every tail binding. That is
    deferred (D7).
- **L5. Marks are not polymorphic.** The honest type of a prefixing
  handler is "N exactly when its outer Log is N", which cannot be written
  (review I2).
  - Workaround: two helpers, `prefix` and `prefixNofail`, or inline
    handlers, whose marks are metas.
  - The same invariance rejects a handler parameter with an M clause row
    installed under a `nofail` own row (§6). Directional `with`
    consumption (ρ ⊑ R, D7) would accept it.
  - Fix: equality-only mark variables in signatures (D6).

## 8. Proposed spec text (applied on approval)

- **§1 reserved words:** `nofail` is contextual, like `pure`.
- **§2:** add a paragraph on marks after "Consumption and opening",
  condensing §3.1-§3.5.
- **§2 `defer` rule:** append "every other label it performs must be
  marked `nofail` once the declaration settles; a label of a handler that
  may fail, or of a signature written without `nofail`, is E_EFFECT
  `defer must not fail, but it performs L, whose handler may fail`."
- **§2 `handler` rule:** `Handler(m L with R)`, clause own rows with late
  consumption, and the constraints.
- **§3 "Cleanup failures":** after "an open row tail", add "or perform an
  operation whose handler may fail (FX008)".
- **§5 probe 6:** add §9's rejections and acceptances.
- **§5 regression proofs:** add §9's mutants.

## 9. Verification (for the plan)

Rejections, each asserted with exact text, primary span and notes:
- the pinned program and the §1 cross-function form (C1);
- `run(handler Log { log(n) => fail(E) })` with a `Handler(nofail Log)`
  parameter;
- `fn mk(): Handler(nofail Log) = handler Log { log(n) => fail(E) };`;
- a `nofail` call under an M signature;
- a handler demanded N whose clause fails, calls an ambient callback, or
  logs to an M outer handler;
- `nofail Fail(E)`;
- review C2's late-`Fail` program, which is still `Unhandled Fail(E) in
  main`, in both registration orders.

Acceptances, with run output:
- an N signature under a fail-free handler;
- a failing inner handler logging to an N outer handler;
- one fail-free handler serving an M callee and an N callee;
- the three opening positions;
- Console cleanup;
- the migrated fx-cleanup program.

Limitations pinned as rejections: L4 (both I1 programs) and L5 (the I2
program).

Other checks:
- unifier properties with marks;
- linearity: 8,000 defers and 1,000 nested handlers settle in linear
  time.

Termination review probes (.build/fx008-probes/), each with its expected
outcome:
- n1 and dup: rejected, under a timeout;
- cycle2open, f1, f2, f3, argbind: accepted, with today's output;
- rigid: rejected (T1);
- argbind with the clause-tail pass mutated: accepted (the mutant is
  caught).

Termination (N1): the never-called-lambda program of §6 and the
no-`defer` clause form each terminate with the side-condition error,
under a test timeout.

Isolated regression mutants, each caught:
- seeding from demands only (cross-function program accepted);
- the per-key cycle weight replaced by key presence (dup hits the
  timeout);
- the exit test counting only feed-edge extensions (argbind's late `Fail`
  never reaches R);
- the clause-tail pass dropped (rigid accepted);
- clause late consumption dropped, or `Fail` filtered from it (C2 program
  accepted);
- clause rows shared with R (a precision acceptance fails);
- marks opened inside parameter rows (unsound acceptance caught);
- the clause edge unified instead of ⊑ (inner/outer acceptance fails).

Differential testing:
- Keep the pinned oracle test, and add a compiler-rejection assertion for
  the same source.
- Add a one-way soundness differential (review M9). Generate failing
  clauses and `defer`s without restriction, and assert that whenever the
  compiler accepts a program, the oracle never reports `typed abort
  escaped cleanup`.
- The default corpus lifts the fail-free-clause restriction and keeps 0
  differences.

## 10. Implementation outline and cost (not authorized)

Touched modules:

| Module | Change |
|---|---|
| Domain.Row | mark field |
| Parse, Resolve | `nofail`; Console normalized |
| Unify, UnifyRow | marks on match |
| Use, Stages | opening positions 1-3 |
| Handler | clause own rows |
| Defer | one late-consumption fixpoint over defers and clauses |
| Features.Check.Mark (new) | seeds, edges, blocks, solve |
| DeferNotes, RowName | notes, printing |
| Domain.Problem, Format.Diagnostic | new kinds |
| Check-to-IR boundary | strip marks, including inside `THandler` |
| Instantiation | `admissible` ignores marks |
| oracle parser, generators, tests | — |

`Label` is built or matched at about 100 sites in about 20 modules
(review M2), so expect more than Task 8 plus its fix round. FX001 Tasks
11-12 follow, and Task 12's ADR 010 records the rule.

With D6 and D7 deferred, Task 11 stays workable, because its handlers are
built inline in `main` (re-review). On approval, Task 11 Step 1 is
amended:
- `nofail` along every cleanup call chain;
- real and fake handlers selected by `if`/`match` share one mark, so each
  handler that a cleanup reaches is fail-free in both forms, or handles
  its failures inside its clauses;
- no callbacks in clauses on cleanup paths;
- no top-level forwarding helpers (L5).

The dropped-handler diagnostic and the key-count baseline are
unaffected.

## 11a. User decisions (2026-10-10, interview)

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

## 11. Decisions for the user

- **D0. Interpretation.** Confirm A1-A3 (§0), including the newly
  rejected programs in §6.
- **D1. Approach.** A (marks, recommended), B (totality per effect), or C
  (inferred marks).
- **D2. Spelling.** `nofail` (recommended: contextual, reads as a promise
  about the handler). Alternatives: `steady`, or a suffix `Log!`. Not
  `total`, which suggests termination.
- **D3. Opening positions 2 and 3** (recommended).
  - Position 2 lets a handler that is demanded N elsewhere also be passed
    to a `Handler(Log)` parameter.
  - Position 3 lets a `nofail` result join M-typed values.
  - Without them, both cases are type errors.
- **D4. CF001 wording** (§4.4): apply now, or with FX002.
- **D5. FX007** re-scoped to `nofail ...e` (§4.5), still deferred.
- **D6. Mark variables** (L5), for example `Handler(k Log with k Log)`.
  They would be equality-only, quantified per signature, instantiated
  fresh per use, and rigid in the body, where demanding N of one is an
  error. They need no scheme constraint. Options: now (more scope), or a
  follow-up item. The follow-up is recommended, because FX001's scenario
  builds handlers inline, where marks are metas.
- **D7. Directional consumption** (L4): a follow-up item (recommended), or
  part of FX008.

## 12. Outside advice (2026-10-10; not the user's decisions)

The user shared outside advice and asked that it be treated as advice
only. D0-D7 remain open. Its technical points, recorded here:

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
