# Concurrency foundations: design investigation (CF001)

Status: Proposed design investigation (CF001); not authorized for
implementation; pending user review.

Requirements: the user's concurrency-foundations brief of 2026-10-09
(.superpowers/sdd/2026-10-09-effects-plan/cc-requirements.md, local
ledger). Ground truth: effects spec docs/plans/2026-10-09-effects-design.md
("spec"), plan docs/plans/2026-10-09-effects-plan.md, shipped Tasks 6-7.
Statements about Task 8 code are **per spec; to be reconciled with the
Task 8 commit** (Task 8 is being implemented in this tree while this is
written). Everything below is proposed unless marked "shipped".

## 1. Purpose, scope, non-goals

Purpose: decide, before concurrency (FX002), local mutable state (FX003)
and general resume (the spec's "FX004"; see §11 on the ID collision),
which guarantees Waxwing can obtain from types, effect rows, lawful
abstractions and runtime boundaries, so that programmers do not manage
synchronization and the runtime stays small. Output: a property
taxonomy, an assessment of candidate approaches against primary sources,
task-boundary and cancellation rules, a failure-selection policy, a
recommended initial subset (CF001) with labeled proof obligations, and a
documentation audit.

Non-goals: no scheduler, worker pool, channels, async I/O, timeouts,
supervision, mutable cells, user-declared laws, or new syntax is
authorized. Syntax in examples is hypothetical and labeled so.

## 2. Shipped baseline and its contracts (Tasks 6-8)

| Contract | Guarantees | Does not guarantee |
|---|---|---|
| Row erasure (Task 6, shipped; Specialize/Lower header, spec §4) | Go types depend on types inside labels, never on row structure; one key per function per type instantiation | Any runtime record of which effects a function value may perform |
| Immutable evidence list (Task 7, shipped; Format/Go/Context.purs) | `waxwingCtx{key, handler any, outer, marker}` nodes are never mutated after allocation; install allocates, leaving needs no pop | That the *handler* a node points to is safe to call from two goroutines: immutability of the node says nothing about resources its clauses touch |
| Dynamic selection (Task 7) | `waxwingFind` walks to the innermost frame for the key at perform time; clauses run with the frame's `outer` (clause context) | That a label identifies a resource: `Log` in a row names an interface whose implementation is chosen at run time and may differ per call site |
| Targeted aborts (Task 7) | `fail` panics with `&waxwingAbort{target}`; only the `handle` helper owning `target` recovers it; all others re-panic | Anything across goroutines: Go `recover` sees only panics on its own goroutine, and an unrecovered panic in any goroutine terminates the process without running other goroutines' deferred functions |
| Cleanup (Task 8, per spec; to be reconciled) | LIFO, once per recoverably exiting activation, in the registration context; `defer` may not perform an unhandled `Fail` (spec §2) | Cleanup on Go fatal errors (stack exhaustion, out of memory, and in future `concurrent map writes` or "all goroutines are asleep"); that a pending typed abort reaches its `handle` (it does only if every cleanup it passes completes normally) |
| Defects (Task 8, per spec) | Uncatchable; pending cause first, cleanup causes after, one report from `main`'s recovery wrapper | Recovery of a defect raised on a goroutine other than `main`'s |
| `with pure` (spec §2, §3 `crash`) | The closed empty effect row: no operation, no typed failure | Termination or freedom from `crash`/guard/Go runtime panics; so an empty row alone does not justify reordering or parallelizing while keeping observable failure behavior (§6) |

Task 8 interaction, precisely (spec §3 "Cleanup failures"): a typed abort
pending while blocks unwind reaches its target `handle` iff every deferred
expression run on the way completes normally; if one raises a recoverable
defect the abort becomes the first cause of the fatal report; if one
diverges, nothing is reported. The in-progress Task 8 runtime keeps
pending state in per-activation locals (a cleanup slice per block helper,
`recover` in `waxwingCleanup`) and recovers the final defect only in
`main`'s wrapper (to be reconciled with the Task 8 commit). Both facts
matter in §5.

## 3. Property taxonomy (as used here)

- **Type/effect soundness.** A well-typed program never performs an
  operation without a handler in its current context (the `no handler`
  guard is unreachable), every `fail` finds a live target marker, and
  every value has its static type. Across tasks: the same, per task.
- **Race freedom.** (a) *Data-race freedom*: no two concurrent accesses
  to one mutable Go location, at least one a write, unordered by
  happens-before (Go races on interfaces/slices can break memory safety).
  (b) *Atomicity*: an operation on a shared resource is observed as
  indivisible. (a) is a safety property; (b) is per-resource.
- **Determinism.** The observable outcome (stdout trace, result, stderr
  report, exit status) is independent of scheduling. *Quasi-determinism*
  (Kuper et al. 2014): every run yields the same outcome or an error.
- **Deadlock freedom.** No reachable state in which a set of tasks waits
  cyclically and none can proceed. Go detects only total deadlock, as a
  fatal error that skips cleanup; partial deadlocks are silent.
- **Cancellation safety.** When a task is cancelled, each registered
  cleanup runs exactly once, no pending cause is lost, shared resources
  keep their invariants, and cancellation completes unless a shielded
  cleanup itself diverges.

These are independent: a pure fork-join is race-free and deterministic;
two children printing through a synchronized Console are race-free but
not deterministic; a correct lock protocol can deadlock.

## 4. Assessment of approaches

| Approach | Guarantee (source) | Assumptions | Compiler checks | Runtime left | Excludes |
|---|---|---|---|---|---|
| 4.1 Regions / read-write effects | Pairwise non-interfering parallel branches behave as their sequential elision, hence deterministically (DPJ, Bocchino et al. 2009; effect systems: Lucassen & Gifford 1988) | every mutable location named by a region; sound summaries; no unchecked foreign code | effect inclusion; disjointness at each parallel construct | fork/join only | branches touching one region, even commutatively (DPJ adds trusted commutative annotations) |
| 4.2 Ownership, linear/affine capabilities | Data-race freedom from "unique owner or shared immutable", with Send/Sync-style crossing rules; RustBelt (Jung et al. 2018) machine-checks a Rust core and states verification conditions for libraries using unsafe code | those library conditions are proved | affine use, borrows, derived sendability | none for safety; a few verified synchronizing libraries | aliasing of mutable data |
| 4.3 Applicative independence | `f <$> a <*> b` shows `b` does not use `a`'s result, so independent fetches can be batched and run concurrently (Haxl, Marlow et al. 2014) | fetches are reads of data that does not change during a run (cached), so their order is unobservable | typing only | batching scheduler | anything whose order is observable |
| 4.4 Commutative effects | discard/copy/swap are valid exactly when the effect theory validates them (Kammar & Plotkin 2012) | the handler is a model of the theory | membership in a declared commuting set | atomicity of each operation when interleaved | operations returning schedule-dependent information (reads) |
| 4.5 Graded / indexed monads | semantics and soundness of effect systems over a preordered monoid of effects (Katsumata 2014) | sequential composition; parallel needs extra structure | grade arithmetic | none | (a framework, not a feature) |
| 4.8 Structured concurrency, task-local state, shared capabilities | children cannot outlive their scope; join orders their effects before the parent continues; failures have a destination; wait-for graphs are trees (Leijen 2017: async on handlers with block-scoped interleaving, cancellation, timeouts, strand-local ambient state; OCaml 5, Sivaramakrishnan et al. 2021: one-shot continuations, unused ones discontinued; Ahman & Pretnar 2021: signals and interrupts) | resources reach tasks only as task-local handlers or explicit capabilities | scope structure; what may cross (B3) | join, cancellation delivery, a small set of synchronized capabilities | detached tasks; implicit sharing |

Verdicts for Waxwing:

- **4.1** The right *shape* of argument, but Waxwing labels are not
  regions: `State(Int)` in two branches may be one shared handler or two
  private ones, chosen dynamically; disjointness would need handler-
  instance identity in types, which first-class handlers (D7) and erasure
  (§8) do not carry. Usable only in the degenerate form "no mutable state
  reachable", which `with pure` and Fail-only code already satisfy.
- **4.2** Too large as a general feature now. Adopt the classification:
  a value crossing a task boundary must be Shareable (immutable data,
  functions, FX001 stateless handlers, trusted runtime capabilities) or,
  later, Transferred (affine move). A structural type-derived predicate,
  no borrow checker.
- **4.3** Independence is a *dependency* fact, not a *commutation* fact:
  `State` satisfies the Applicative laws while its order is observable.
  FN001 fixes left-to-right argument order, so parallelism must be an
  explicit construct, never inferred from argument position.
- **4.4** Commutativity belongs to the handler, which Waxwing selects at
  run time; a guarantee is possible only when every handler of the label
  is a trusted built-in or carries a proof. Commuting writes are not
  enough once reads observe them (Kuper et al. 2014). Not in CF001.
- **4.5** A proof framework for row soundness and a parallel rule (the
  vehicle for O2 if mechanized), not a language feature (it needs K001).
- **4.8** The boundary model for Waxwing; CF001 takes its fork-join core.

**4.6 Lattices, LVars, lawful reductions.** LVars (Kuper & Newton 2013):
shared variables whose states form a join-semilattice; writes take the
least upper bound; reads are threshold reads that block until the state
is at or above an element of one of a set of pairwise-incompatible
activation sets (incompatible: their join is top). Result: determinism,
with top as a deterministic error. Freeze/handlers (Kuper et al. 2014):
exact reads after freezing yield quasi-determinism (same answer or an
error; an error arises when a write follows a freeze). CRDTs (Shapiro et
al. 2011): sufficient conditions for convergence, semilattice state or
commuting concurrent operations. Laws needed, by guarantee:

| Construct | Laws | Guarantee | Extra condition |
|---|---|---|---|
| Parallel reduce, runtime-chosen tree shape, ordered leaves | associative + identity (monoid) | equals sequential fold | combiner pure and total |
| Unordered reduce (combine as children finish) | commutative monoid | deterministic result | each contribution exactly once |
| Shared accumulator, read only after join | commutative monoid | deterministic final value | structured join orders the read |
| Accumulator read during the run | join-semilattice + threshold reads | determinism (LVars) | activation sets pairwise incompatible |
| Exact read before writers finish | semilattice + freeze | quasi-determinism | error if a write follows the freeze |
| Retried / duplicated contributions | + idempotence (semilattice) | convergence | as CRDT state merge |

Concrete: Waxwing `Int` addition wraps modulo 2^32 (docs/language.md),
so `(+, 0)` is a commutative monoid (ESTABLISHED, modular arithmetic);
future floating point (D001) is not associative, so a parallel float sum
is not deterministic under a runtime-chosen shape.

**4.7 How laws are established.** In decreasing strength: (1) compiler
restriction (only constructs whose laws hold by construction, e.g. the
built-in `Int` add); (2) proof (paper or mechanized, for a built-in);
(3) trusted built-in supported by tests; (4) user obligation supported by
property tests (PBT001). A type-class instance declaration is never a
proof (C001/STD001 must not treat `instance Monoid` as evidence). Policy
proposed for all of Waxwing: a user-asserted law may affect *which value*
a program computes (determinism, result equality), never type soundness,
data-race freedom, cleanup or report integrity. An unlawful user
combiner may give schedule-dependent results; it must not crash the
runtime or corrupt memory.

## 5. Task-boundary rules (proposed)

Syntax here is **hypothetical**. `par let x = e1, y = e2;` is a block
item that evaluates `e1` and `e2` as child tasks and binds both after
both join.

**B1. Lookup inherited, unwinding local.** A child starts with the
parent's context at the fork *for lookup* (immutable nodes, published to
the goroutine before it starts, so reading them is race-free under Go's
happens-before for `go` statements). A child never unwinds the parent's
stack. Every child runs under a root wrapper that recovers every
recoverable panic on its goroutine. An abort whose target marker is not
owned by a `handle` inside the child is caught by the child root, after
the child's own cleanup ran, and recorded as the child's outcome; the
parent re-raises it, unchanged, at the join, on the parent's goroutine.
Structured scoping keeps the target live: its `handle` encloses the
`par`, and the parent is blocked at the join.

```
// hypothetical
handle {
  par let a = load(1), b = load(2);   // load: Int -> Row with Fail(DbError)
  merge(a, b)
} { fail(error: DbError) => empty() }
```

`load(2)` failing inside its goroutine panics toward the outer
`handle`'s marker; without B1 no frame on that goroutine owns it and the
process dies without running the parent's cleanup. With B1 the child
root records it and the parent re-raises it at `par`.

**B2. Clauses run on the child.** A parent-installed handler reached by
a child runs its clause on the child's goroutine, in the handler-site
context (spec §3 unchanged). Hence a handler may cross only if it is
Shareable (B3). A clause's own `fail` targeting a parent `handle` is
covered by B1.

**B3. Sharing versus transfer.** Shareable: immutable data, function
values, FX001 handlers (their clauses close over immutable values; no
cells exist), and trusted runtime capabilities. Not Shareable: FX003
local-state handlers, captured continuations, foreign handles until I001
classifies them. Transfer (affine move into exactly one child, returned
at join) is deferred: it needs affine checking. The predicate is
structural over types plus a per-effect declaration attribute (§8).

```
// hypothetical, FX003-era
with counter(0) {                     // local-state handler (not Shareable)
  par let a = tick(), b = tick();     // rejected: both children reach counter
}
par let a = with counter(0) { tick() }, b = with counter(0) { tick() };
                                      // accepted: task-local state
```

**B4. Child failures.** A child's outcome is a value, a typed abort
(B1), or a defect with its cause list (its own cleanup causes appended,
spec §3). The parent waits for the outcomes the policy of §6 needs, then
either binds the values or re-raises the selected outcome at the join:
an abort keeps its target; a defect stays uncatchable and its causes
start the parent's report. Defects are not caught at the boundary
(catching defects remains deferred supervision, D9).

**B5. Child-local constructs.** `with`, `handle`, markers and `defer`
inside a child belong to the child; its cleanup runs on its goroutine
before its outcome is published (exactly once, spec §3 unchanged).

## 6. Equivalence and failure selection

Intended equivalence for CF001: **sequential equivalence**. `par let
x1 = e1, …, xn = en;` has the observable outcome of `let x1 = e1; …; let
xn = en;` evaluated left to right, for outcomes in {value, typed abort,
recoverable defect with its cause list, divergence}. Resource exhaustion
(Go fatal errors: stack, memory) is outside the semantics today (spec §3
"Defects") and is excluded from the equivalence.

Failure-selection policy (leftmost): let i be the least index whose child
did not produce a value. The parent waits until children 1..i-1 have all
produced values and child i has finished, then re-raises child i's
outcome. Children right of i are *discarded*: their outcomes, including
defects, are never observed. If some child j < i diverges, the whole
construct diverges, exactly as the sequential program would.

Why this needs restricted rows: discarding is equivalent to never having
run only if the discarded children performed nothing observable. That
holds when a child's row contains only `Fail` labels (or is `with pure`):
it can abort, crash or diverge, and nothing else is observable. With any
other label (Console, user services) the right siblings' effects already
happened, so no policy can be sequentially equivalent.

```
// hypothetical
par let a = spin(), b = crash("x");   // sequential: diverges (spin first)
                                      // CF001: diverges (waits for a)
par let a = crash("x"), b = spin();   // sequential: reports crash: x
                                      // CF001: reports crash: x; b discarded
```

Discarded pure children cannot be stopped in Go (no asynchronous goroutine
termination). Since a non-value outcome of a Fail-only child is either an
abort (the parent continues; discarded children keep burning CPU until
they finish) or a defect (the program reports and exits), CF001 accepts
CPU leakage of discarded children as a documented cost; cooperative
cancellation polls are an FX002 decision. Residual non-equivalence: a
discarded child can hit a fatal error (stack, memory) before the program
exits; excluded above.

Effectful children (FX002) cannot have sequential equivalence. Options to
settle there: leftmost-by-index among finished children (deterministic
given the outcome set) versus first-to-finish; whether other children's
defects are appended as secondary report lines; whether additional typed
aborts are dropped (losing a recoverable error) or forbidden statically.

## 7. Cancellation as a future block-exit reason

Spec §3 lists four exits (normal, typed abort, recoverable defect, future
continuation discard). Proposed fifth: **cancellation**, requested by a
parent scope (sibling failure, timeout) and delivered to a task only at
cancellation points. Rules proposed for FX002:

- **C1 Delivery.** Cooperative only (Go cannot interrupt a goroutine):
  at operation performs, `with`/`handle` entry and explicit polls.
  Foreign calls (I001) are not interruptible: latency across a foreign
  frame is unbounded unless I001 adapters poll.
- **C2 Not a failure.** Cancellation is not a typed failure and is not
  caught by `handle`; it unwinds to the task root and is not a report
  cause. If a typed abort or defect is already pending, cancellation is
  absorbed and the pending cause is kept.
- **C3 Exactly-once cleanup.** Each activation's deferred expressions run
  once whatever the exit reason; a cancellation request arriving during
  cleanup does not restart or skip cleanup.
- **C4 Shielding.** Cleanup is shielded by default: cancellation is
  masked while deferred expressions run. An explicit shield form for
  ordinary code (hypothetical `shield { … }`) is optional and later.
- **C5 Suspending cleanup.** Cleanup that waits (await, I/O) can deadlock
  if it awaits a task that is itself waiting for this task's scope.
  Proposed rule: cleanup may wait only on tasks it starts itself; a
  static check is a decision for FX002, and a runtime check is possible.
- **C6 Continuation ownership (general resume).** A captured continuation
  is affine and owned by the clause activation that captured it: resumed
  once, or discarded once; discard is the "continuation discard" exit and
  runs the captured frames' cleanup (as OCaml 5's discontinue). A task
  that is cancelled while owning an unresumed continuation discards it.
  Continuations are not Shareable (B3) and do not cross tasks.
- **C7 Unresolved.** Multi-shot resumption of continuations containing
  `defer` remains explicitly unresolved (spec §3), as does whether cleanup
  in a multiply resumed continuation runs per resumption.

## 8. Information that must survive checking

Row erasure (Task 6) can remain. What future work needs, and where:

| Need | Where | Erasure impact |
|---|---|---|
| CF001: child rows are Fail-only | Check, at the `par` item (same pattern as Task 8's `defer` rule: check under a fresh row, settle, inspect labels) | none |
| B3: Shareable classification | Check, from types plus a declaration attribute on effects (e.g. hypothetical `local effect Counter`); `EffectInfo` in the IR may carry it for runtime assertions | none: derived from declarations, not rows |
| FX002 async on goroutines | none: goroutines are stackful, so blocking needs no CPS and no suspension analysis | none |
| FX004 general resume (`ctl`): which code may capture | post-specialization analysis over the IR call graph and function-value flow, keyed by an `EffectInfo` control kind (resuming / general) | conservative merging of all function values of one `FunType`; if too imprecise, a suspension bit on IR arrow types, i.e. bounded row-aware re-specialization, already named in spec §4 "Revision of direction decision 1" |
| Determinism of lawful reductions (later) | identity of trusted built-in combiners in the IR | none |

Genuine incompatibility arises only if general resume is implemented by
CPS and the suspension bit must enter specialization keys; that is the
existing, recorded revision of decision 1, not new. CF001 and FX002 as
proposed need no IR change beyond the new fork-join node.

## 9. Recommendation: CF001

**Subset.** One built-in structured fork-join construct (hypothetical
`par let x1 = e1, …, xn = en;` block item; spelling for the user) whose
children are checked to have Fail-only rows (closed or `Fail` labels only),
with sequential-equivalence semantics and leftmost failure selection
(§6), child root wrappers and abort transfer at the join (B1, B4). No
shared mutable state, no effectful children, no cancellation of running
effects, no user laws. This is exactly the part where established theory
(noninterference ⇒ sequential equivalence) applies with no new type
machinery, and it fixes the boundary rules every later milestone needs.

**Core semantics sketch.** Configuration: parent blocked at `par` with
child outcomes `o1..on`, each ⊥ (running), `V v`, `A (m, p)` (abort,
target marker m, payload p) or `D cs` (defect, causes). Child k runs `ek`
with the parent's context Γ for lookup and an empty unwind stack; its
cleanup runs inside the child (spec §3). Join rule: if all `ok = V vk`,
bind `xk = vk`, continue. If the least i with `oi ∉ V` has `oi ≠ ⊥` and
all `oj = V` for j < i, re-raise `oi` in the parent (abort → panic with
target m on the parent goroutine; defect → defect with causes `cs`, then
parent cleanup causes appended). Otherwise wait. Discarded children's
outcomes are ignored.

**Proof obligations.**

| # | Obligation | Status |
|---|---|---|
| O1 | Fail-only children share no mutable state: FX001 values and handlers are immutable, and the generated Go for Fail-only code writes only goroutine-local locals and fresh allocations | PROPOSED PROOF (over the Go lowering contract) + TEST-ONLY (`go build -race` runs of the CF001 corpus) |
| O2 | Boundary soundness: a Fail-only child needs no operation handler; every abort it raises targets a marker of a `handle` enclosing the `par`, live at the join (structured scoping lemma) | PROPOSED PROOF (by typing; Katsumata-style graded semantics if mechanized) |
| O3 | Non-interfering parallel branches behave as their sequential composition | ESTABLISHED (DPJ, Bocchino et al. 2009) given O1 |
| O4 | Sequential equivalence with leftmost selection for {value, abort, defect, divergence} | PROPOSED PROOF (from O1-O3 and §6's discard argument) |
| O5 | Deadlock freedom: children wait on nothing; the parent waits only on its children; the wait-for graph is a tree | PROPOSED PROOF (immediate) |
| O6 | Exactly-once cleanup per child activation; child defect causes ordered as sequentially | PROPOSED PROOF (spec §3 applied per goroutine) + TEST-ONLY |
| O7 | Every recoverable panic on a child goroutine is recovered by its root; no child panic escapes to the Go runtime | TEST-ONLY (injected crashes, guard panics, Go runtime panics) |
| O8 | Go happens-before for `go` statements and the join primitive (WaitGroup/channel) publishes Γ and outcomes | ESTABLISHED (Go memory model) |
| O9 | Fatal errors and CPU use of discarded children are outside the equivalence | TEST-ONLY (documented limitation, probes) |

Oracle: the FX001 reference interpreter (plan Task 10) running `par`
sequentially is the specification; differential runs with randomized
schedules (sleeps/yields injected in children) compare stdout, report and
exit status.

Explicitly not guaranteed by CF001: determinism or race freedom for
effectful children; cancellation safety (nothing cancellable runs);
lawful reductions (CF002 candidate: built-in `Int` sum, then user monoids
as user obligations with PBT001 tests, per §4.7).

## 10. Handoff

**Settle before concurrency (FX002), mutable state (FX003), resumable
handlers (spec "FX004"):**
1. B1 (lookup inherited, unwinding local, abort transfer at join): before
   FX002; it constrains the runtime shape of every task.
2. Shareability classification (B3) and its declaration attribute: before
   FX003, because a state handler's type must say whether it may cross.
3. Law-establishment policy (§4.7): before C001/STD001 publish `Monoid`
   or `Semigroup`, so instances are never treated as proofs.
4. Cancellation as an exit reason and C2-C4: before FX002 and before
   general resume, since discard and cancellation share the cleanup path.
5. Continuation ownership C6 (one-shot, affine, task-local): before
   general resume.
6. Whether effectful parallelism promises anything beyond race freedom
   (recommend: no determinism promise; leftmost selection by default).

**Can wait for runtime implementation:** goroutine-per-child versus a
pool; join primitive; poll placement and cost; Console line atomicity
mechanism; chunking of large `par`; whether discarded pure children get
polls; cached lookup (FX005); goroutine- versus CPS-backed one-shot resume.

**Necessary changes to the existing design** (spec text, not code):
1. §3 "Block exits": make the list open and name cancellation as a future
   reason. Example: `par let a = { let c = open(); defer close(c);
   use(c) }, b = fail(Timeout);` (FX002-era, hypothetical) must run
   `close(c)` when `a` is cancelled; that exit is not an abort, defect or
   discard.
2. Direction decision 4 and resume-readiness: add the B1 boundary rule.
   Example: §5's `handle { par let a = load(1), b = load(2); … }` crashes
   the process without parent cleanup if a child inherits the parent's
   marker and panics on its own goroutine.
3. §3 "Cleanup failures" and the `with pure` sentence in §1: correct the
   over-promises listed in §11 (wording only).
No change is needed to row erasure, to the evidence-context
representation, to markers, to the `defer`-must-not-fail rule or to the
defect report format.

**Compatibility of Tasks 6-8.** Task 6: compatible (§8); the only
incompatibility is the already recorded CPS case of general resume.
Task 7: compatible; immutable nodes make inherited lookup race-free, and
goroutine-local recovery requires one additive runtime piece (child root
plus re-raise at join). Task 8 (per spec; to be reconciled with the Task
8 commit): compatible; per-activation cleanup state is goroutine-safe, and
`main`'s wrapper needs the child root to forward child defects to it.
None of Tasks 6-8 needs to be undone.

## 11. Documentation audit (corrections for the controller to apply)

Seven over-promises (file:line, quoted, then proposed wording), plus one
ID inconsistency. D = docs/plans/2026-10-09-effects-design.md.

1. D:46-47 "cancellation are a follow-up milestone on the same evidence
   model." → "… a follow-up milestone (FX002) building on the evidence
   model, subject to task-boundary rules (CF001 design): children inherit
   the context for lookup but never unwind the parent's stack."
2. D:49-51 "specified to remain sound under future captured
   continuations." → "intended to remain sound under future one-shot
   continuations (section 3, Block exits); multi-shot continuations
   containing `defer` are unresolved."
3. D:75-77 "Defects are uncatchable; cleanup still runs. … running
   deferred cleanup on the way." → "Recoverable defects are uncatchable;
   cleanup still runs. … running deferred cleanup on the way; Go fatal
   errors (stack exhaustion, out of memory) skip cleanup (section 3)."
4. D:125 "Omission is not a promise of purity; `with pure` is." →
   "Omission is not a promise of an empty effect row; `with pure` is. It
   promises neither termination nor freedom from `crash` (section 3)."
5. D:341-343 "exits for exactly one of four reasons: … Its deferred
   expressions run exactly once per exiting activation." → "exits for
   exactly one reason: normal completion, typed abort or recoverable
   defect in FX001; continuation discard and cancellation are future
   reasons. Its deferred expressions run exactly once per exiting
   activation; a Go fatal error is not an exit and runs none."
6. D:349-354 "a typed failure pending while the block unwinds always
   reaches its own `handle`, and no typed error is ever lost or converted
   … so nothing recoverable is lost" → "a typed failure pending while
   blocks unwind reaches its own `handle` if every deferred expression run
   on the way completes normally; no typed cleanup failure can replace,
   drop or convert it. … If cleanup raises a recoverable defect, the
   pending abort stops being recoverable and becomes the first cause of
   the report (below); if cleanup diverges, it is never delivered."
7. docs/progress.md:3034-3035 "Only defects can fail cleanup, so a
   pending typed abort always reaches its `handle`." → "Only defects can
   fail cleanup, so a pending typed abort reaches its `handle` unless a
   cleanup on the way raises a defect (the abort then heads the defect
   report) or diverges."

Checked and accurate: effects-plan.md:526-530 (abort reaches its
`handle` after cleanup completes normally) and :657-658; docs/findings.md
:371-375 ("never converted by a typed cleanup failure");
docs/next-session.md:17-18 ("only defects can fail cleanup").

ID inconsistency: BACKLOG.md:75 uses FX004 for the finished Task 5
validation gaps; D:672-673, D:779 and effects-plan.md:661-662 reserve
FX004 for general resume. Give general resume a fresh ID (e.g. FX006) or
rename the Task 5 row; the user chooses.

## 12. References

Verified in this session: title, authors, venue, year, and the cited
claim against the abstract or a summary. Re-read theorem wording in the
full text before writing any proof.

- Lucassen, Gifford. Polymorphic effect systems. POPL 1988, 47-57.
- Bocchino et al. A type and effect system for Deterministic Parallel Java. OOPSLA 2009, 97-116.
- Kuper, Newton. LVars: lattice-based data structures for deterministic parallelism. FHPC 2013.
- Kuper, Turon, Krishnaswami, Newton. Freeze after writing: quasi-deterministic parallel programming with LVars. POPL 2014, 257-270.
- Marlow, Brandy, Coens, Purdy. There is no fork: an abstraction for efficient, concurrent, and concise data access. ICFP 2014, 325-337.
- Kammar, Plotkin. Algebraic foundations for effect-dependent optimisations. POPL 2012, 349-360.
- Katsumata. Parametric effect monads and semantics of effect systems. POPL 2014, 633-645.
- Jung, Jourdan, Krebbers, Dreyer. RustBelt: securing the foundations of the Rust programming language. POPL 2018.
- Leijen. Structured asynchrony with algebraic effects. TyDe 2017 (MSR-TR-2017-21).
- Sivaramakrishnan, Dolan, White, Kelly, Jaffer, Madhavapeddy. Retrofitting effect handlers onto OCaml. PLDI 2021.
- Ahman, Pretnar. Asynchronous effects. PACMPL 5 (POPL 2021), article 24.
- Shapiro, Preguiça, Baquero, Zawirski. Conflict-free replicated data types. SSS 2011, LNCS 6976, 386-400.
- Not verified here: the Go memory model (go.dev/ref/mem), cited for O8; check the version current at implementation.
