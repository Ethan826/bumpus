# Concurrency foundations: design investigation (CF001)

Status: Proposed design investigation (CF001); not authorized for
implementation; pending user review. Revised 2026-10-09 after an
adversarial review (findings and responses at the end).

Requirements: .superpowers/sdd/2026-10-09-effects-plan/cc-requirements.md
(user, 2026-10-09). Ground truth: spec docs/plans/2026-10-09-effects-
design.md ("D"), its plan, Tasks 6-7 and Task 8 (041cb31) with the
controller's `defer` ruling (§5 R0). All else is proposed.

## 1. Purpose, scope, non-goals

Purpose: decide, before concurrency (FX002), local mutable state (FX003)
and general resume (FX006; renumbered from the spec's former "FX004", §11), which guarantees types,
effect rows, lawful abstractions and runtime boundaries can give, so that
programmers do not manage synchronization and the runtime stays small.

Non-goals: no general scheduler, channels, async I/O, timeouts,
supervision, mutable cells, user laws or new syntax; example syntax is
hypothetical.

## 2. Shipped baseline and its contracts (Tasks 6-8)

| Contract | Guarantees | Does not guarantee |
|---|---|---|
| Row erasure (Task 6; Specialize/Lower header, spec §4) | Go types depend on types inside labels, never on row structure; one key per function per type instantiation | Any runtime record of which effects a function value may perform |
| Immutable evidence list (Task 7; Format/Go/Context.purs) | `waxwingCtx{key, handler any, outer, marker}` nodes are never mutated after allocation; install allocates, leaving needs no pop | That the *handler* a node points to is safe to call from two goroutines: node immutability says nothing about resources its clauses touch |
| Dynamic selection (Task 7) | `waxwingFind` walks to the innermost frame for the key at perform time; clauses run with the frame's `outer` (clause context) | That a label identifies a resource: `Log` names an interface whose implementation is chosen at run time |
| Targeted aborts (Task 7) | `fail` panics with `&waxwingAbort{target}`; only the `handle` helper owning `target` recovers it; all others re-panic | Anything across goroutines: `recover` sees only its own goroutine's panics, and an unrecovered panic in any goroutine ends the process without running other goroutines' deferred functions |
| Cleanup (Task 8, 041cb31) | LIFO, once per recoverably exiting activation, in the registration context; per-activation `waxwingCleanups` slice, `recover` in `waxwingCleanup`; `defer` rejected if it performs an unhandled `Fail` (label check; see R0) | Cleanup on Go fatal errors (stack exhaustion, out of memory; later `concurrent map writes`, "all goroutines are asleep"); that a pending typed abort reaches its `handle` (only if every cleanup it passes completes normally) |
| Defects (Task 8) | Uncatchable; pending cause first, cleanup causes after; one `waxwingReport` in `main`, emitted only when `usesDefects` | Recovery of a panic on any goroutine other than `main`'s |
| `with pure` (spec §2, §3 `crash`) | The closed empty effect row: no operation, no typed failure | Termination or freedom from `crash`/guard/Go runtime panics; an empty row alone does not justify reordering or parallelizing while keeping failure behavior (§6) |

A pending typed abort that meets a defecting cleanup heads the report;
one that meets a diverging cleanup is never delivered.

## 3. Property taxonomy (as used here)

- **Type/effect soundness.** A well-typed program never performs an
  operation without a handler in its current context (the `no handler`
  guard is unreachable), every `fail` finds a live target marker, every
  value has its static type, and every "performs no X" check holds for
  every instantiation. Across tasks: the same, per task.
- **Race freedom.** (a) *Data-race freedom*: no two concurrent accesses to
  one mutable Go location, at least one a write, unordered by
  happens-before. (b) *Atomicity*: an operation on a shared resource is
  observed as indivisible. (a) is a safety property; (b) is per-resource.
- **Determinism.** The observable outcome (stdout, result, report, exit
  status) is schedule-independent; *quasi-determinism* (Kuper et al.
  2014): the same outcome or an error.
- **Deadlock freedom.** No reachable cyclic wait. Go detects only total
  deadlock (a fatal error skipping cleanup); partial ones are silent.
- **Cancellation safety.** On cancellation each cleanup runs exactly
  once, no pending cause is lost, shared resources keep their invariants,
  and cancellation completes unless a shielded cleanup diverges.

## 4. Assessment of approaches

| Approach | Guarantee (source) | Assumptions | Compiler checks | Runtime left | Excludes |
|---|---|---|---|---|---|
| 4.1 Regions / read-write effects | Pairwise non-interfering parallel branches behave as their sequential elision (DPJ, Bocchino et al. 2009; effect systems: Lucassen & Gifford 1988) | every mutable location named by a region; sound summaries; no unchecked foreign code | effect inclusion; disjointness at each parallel construct | fork/join | branches touching one region, even commutatively (DPJ adds trusted commutative annotations) |
| 4.2 Ownership, linear/affine capabilities | Data-race freedom from "unique owner or shared immutable", Send/Sync-style crossing rules; RustBelt (Jung et al. 2018) machine-checks a Rust core and states verification conditions for libraries using unsafe code | library conditions proved | affine use, borrows, derived sendability | a few verified synchronizing libraries | aliasing of mutable data |
| 4.3 Applicative independence | `f <$> a <*> b` shows `b` does not use `a`'s result, so independent fetches can be batched and run concurrently (Haxl, Marlow et al. 2014) | fetches read data that does not change during a run, so their order is unobservable | typing only | batching scheduler | anything whose order is observable |
| 4.4 Commutative effects | discard/copy/swap are sound when the effect theory validates them; the paper gives sufficient conditions (Kammar & Plotkin 2012) | the handler is a model of the theory | membership in a declared commuting set | atomicity of each operation when interleaved | operations returning schedule-dependent information (reads) |
| 4.5 Graded monads | semantics and soundness of effect systems over a preordered monoid of effects (Katsumata 2014) | sequential composition; parallel needs extra structure | grade arithmetic | none | (a framework) |
| 4.5b Indexed / parameterised monads | computations indexed by pre- and post-state types: state whose type changes, protocol-typed I/O, i.e. which compositions are permitted (Atkey 2009) | indices track the resource state precisely | index unification | none | uses that break the protocol order |
| 4.8 Structured concurrency, task-local state, shared capabilities | children cannot outlive their scope; join orders their effects before the parent continues; failures have a destination (Leijen 2017: async on handlers, block-scoped interleaving, cancellation, timeouts, strand-local ambient state; Ahman & Pretnar 2021: signals and interrupts; OCaml 5, Sivaramakrishnan et al. 2021: one-shot continuations that the programmer must resume or discontinue) | resources reach tasks only as task-local handlers or explicit capabilities | scope structure; what may cross (B3) | join, cancellation delivery, a few synchronized capabilities | detached tasks; implicit sharing |

Verdicts. **4.1** Right shape, but labels are not regions: `State(Int)`
in two branches may be one shared or two private handlers, chosen at run
time; usable only as "no mutable state reachable" (§9, FX001-relative).
**4.2** Too large now; adopt only the Shareable/Transferred
classification (B3). **4.3** Independence is a dependency fact, not a
commutation fact (`State` is a lawful Applicative with observable order);
FN001 fixes argument order, so parallelism must be explicit. **4.4**
Commutativity belongs to the dynamically chosen handler; only trusted or
proved handlers qualify, and commuting writes fail once reads observe
them (Kuper et al. 2014); not in CF001. **4.5** A proof framework (for
O2), not a feature (needs K001). **4.5b** Defer: needs K001 and indexed
types; capability typestate is later subsumed by affine transfer plus
`defer`. **4.8** The boundary model; CF001 takes its fork-join core.

**4.6 Lattices, LVars, lawful reductions.** LVars (Kuper & Newton 2013):
states form a join-semilattice; writes take the least upper bound; reads
are threshold reads against a threshold set of pairwise-incompatible
elements (join is top), giving determinism, with top a deterministic
error. Activation sets, freezing and handlers (Kuper et al. 2014) give
quasi-determinism (error when a write follows a freeze). CRDTs (Shapiro
et al. 2011): convergence from semilattice state or commuting operations.

| Construct | Laws | Guarantee | Extra condition | Established by |
|---|---|---|---|---|
| Parallel reduce, runtime-chosen shape, ordered leaves | associative + identity | equals sequential fold | combiner pure and total | built-in `Int` add: compiler restriction + proof; user monoid: user obligation + PBT001 |
| Unordered reduce (combine as children finish) | commutative monoid | deterministic result | combiner total; each contribution once | as above |
| Shared accumulator, read only after join | commutative monoid | deterministic final value | per-update atomicity (runtime); combiner total; join orders the read | trusted built-in accumulator only |
| Accumulator read during the run | join-semilattice + threshold reads | determinism | threshold set pairwise incompatible | trusted built-in lattices only |
| Exact read before writers finish | semilattice + freeze | quasi-determinism | error if a write follows the freeze | trusted built-in only |
| Retried / duplicated contributions | + idempotence | convergence | as CRDT state merge | trusted built-in only |

`Int` addition wraps modulo 2^32 (docs/language.md): `(+, 0)` is a
commutative monoid (ESTABLISHED); floats (D001) are not associative.

**4.7 How laws are established.** Strongest first: compiler restriction;
proof for a built-in; trusted built-in plus tests; user obligation plus
property tests (PBT001). An instance declaration is never a proof
(C001/STD001 must not treat `instance Monoid` as evidence). Policy: a user-asserted law may affect *which value* is
computed and *which failure* is reported (a crashing combiner makes it
shape-dependent); it must never affect type soundness, data-race freedom,
cleanup, report integrity, or termination of the runtime's own waits.
Hence lattices with blocking reads are trusted built-ins only: a user
lattice with a non-monotone join or overlapping thresholds could block a
read forever or release it nondeterministically.

## 5. Task-boundary rules (proposed)

Hypothetical syntax: block item `par let x = e1, y = e2;` runs `e1`, `e2`
as child tasks and binds both after the join.

**R0. Negative effect restrictions (general rule).** A check that an
expression "performs no X" (`defer`: no `Fail`; `par` child: nothing but
`Fail`; this is the controller's ruling for `defer`, generalized) works
as follows. The restricted expression is checked against its own row with
a fresh meta tail. Its labels are consumed into the enclosing current row
(with a fresh tail there); its tail is never unified with the current row.
After the enclosing function's constraints settle (deferred `Fail` keys
included; labels arriving then are consumed then), any remaining
forbidden label is rejected, a tail resolved to a rigid row variable
(ambient `...` or named `...e`) is rejected, because an instantiation can
supply X there, and an unsolved meta tail closes to empty. Diagnostics
(E_EFFECT): `defer must not fail, but it performs <L>`; `defer must not
fail, but it may perform any effect of <r>`; for `par` (hypothetical
wording) `a par child may only fail, but it performs <L>` and `… but it
may perform any effect of <r>`. Pending user confirmation: this strictness
versus an internal "lacks X" constraint checked at instantiation sites.
Examples, both accepted by a labels-only check:

```
// hypothetical: callers pass printing / failing callbacks
fn both(f: Int -> Int, g: Int -> Int): Int = { par let a = f(1), b = g(2); a + b };
fn after(f: Unit -> Unit): Int = { defer f(()); 0 };
```

Task 8 (041cb31) inspects the labels of the deferred expression's row at
the item (Features/Check/Defer.purs), so `after` is accepted while a
caller's `Fail` can escape cleanup; the ruling above fixes it. Required
rejection tests: both examples.

**B1. Lookup inherited, unwinding local.** A child starts with the
parent's context *for lookup* (immutable nodes published before the `go`
statement). A child never unwinds the parent's stack. Every child runs
under a root wrapper that recovers every recoverable panic on its
goroutine. An abort whose target marker is not owned by a `handle` inside
the child is caught by the root, after the child's cleanup ran, and
recorded as the child's outcome; the parent re-raises it unchanged at the
join, on its own goroutine. The target stays live: its `handle` encloses
the `par` and the parent is blocked at the join (also when `par` sits in
a clause, since clauses resume immediately).

```
// hypothetical
handle {
  par let a = load(1), b = load(2);   // load: Int -> Record with Fail(DbError)
  merge(a, b)
} { fail(error: DbError) => empty() }
```

Without B1, `load(2)`'s panic has no owner on its goroutine; the
process dies without the parent's cleanup.

**B2. Clauses run on the child**, in the handler-site context; their own
effects never appear in the child's row; a clause's `fail` is B1.

**B3. Sharing versus transfer.** Shareability is a property of *types*,
derived transitively: immutable data and function values are Shareable;
`Handler(L with R)` is Shareable only if L is not declared local and
every label in R is Shareable, with R's tail closed (R0-style); bounded
tails are a later alternative needing row constraints. Not Shareable: FX003 local-state handlers, captured
continuations, foreign handles until I001 classifies them. A label-only
check is not enough (B2):

```
// hypothetical, FX003-era
with counter(0) { with logToCounter {          // Log clauses tick()
  par let a = log("x"), b = log("y");          // rows show only Log
} }
let c = counter(0);
par let a = with c { tick() }, b = with c { tick() };  // rows Fail-only
```

Both are rejected: the first by the handler-type rule (the Log clause
row holds local Counter), the second by a Shareable check on captured
free variables. In FX001 every type is Shareable, so it rejects nothing
yet; FX003 cannot land without it. Affine transfer is deferred.

**B4. Child failures.** Outcomes: value, typed abort (B1), or defect with
its causes. The parent binds values or re-raises the selected outcome (§6):
an abort keeps its target; a defect stays uncatchable and its causes start
the parent's report (no supervision, D9). A program with `par` emits the
defect runtime, so forwarded Go runtime panics use Waxwing's format.

**B5. Child-local constructs.** `with`, `handle`, markers and `defer` in
a child are its own; its cleanup runs on its goroutine before its
outcome is recorded (exactly once, spec §3).

## 6. Equivalence, resources and failure selection

**Equivalence (conditional).** Condition, over both runs: the
sequential run `let x1 = e1; …; let xn = en;` incurs no Go fatal error,
and in the parallel run no Go fatal error occurs in the process while any
goroutine started by the construct (inline, nested and discarded
included) is live. Under it, `par let x1 = e1, …, xn = en;` has the
sequential observable outcome over {value, typed abort, recoverable
defect with its cause list, divergence}. Assumption: every divergent
computation makes unboundedly many calls (Waxwing has no loop construct,
and current lowering emits only bounded runtime loops), so function-entry
polls reach it. The condition is not checkable statically.

**Execution and discard (part of CF001).**
- *Bounded live tasks.* At most B child goroutines are live program-wide
  (B a runtime constant, e.g. a small multiple of GOMAXPROCS). Over
  budget, a child runs inline on the parent goroutine, after the spawned
  ones are started, in index order. So `fib(n) = par let a = fib(n-1),
  b = fib(n-2); a + b` holds at most B extra goroutine stacks.
- *Every child has a root.* Spawned and inline children alike run under a
  root wrapper with its own task record: it recovers the child's outcome
  and records it, never raising it, so an inline child's abort cannot
  pre-empt a crash of a spawned child to its left.
- *Eager discard.* When child j's root records a non-value, it discards
  every sibling with index > j (safe: the selected index is at most j).
  An inline child not yet started is skipped; a running one unwinds at its
  next poll to its root, which records "discarded" (`X`). So `par let a =
  fail(E), b = spin();` with `b` inline aborts, as sequentially.
- *Propagation to nested `par`.* Each task record links its live
  children (registered at fork). Discarding a task sets its flag and,
  transitively, its live descendants' flags; a task forked by an already
  discarded task starts discarded. Exception: a task forked while its
  parent is in cleanup (a `par` inside `defer`) is shielded, together with every task it forks: propagation skips that
  subtree, so the cleanup's `par` runs to its normal join (P4). Example: `par let a = fail(E), b = { par let c = grow(nil),
  d = 1; c };` discards `b`, hence `c`, which stops at its next call.
- *Polls.* Function entry and every join are poll points. A poll is a
  nil-checked load of the task pointer plus an atomic load of its flag;
  it does not fire while the task runs deferred expressions. A discarded
  task waiting at its own join abandons it and unwinds. Setting a flag therefore wakes a blocked join, and a fork reads its parent's flag and registers under the same lock, so a child forked concurrently with a discard is flagged either way. The join does not
  wait for discarded children; they release their budget slot on exit.
- *Stack and memory.* A spawned child starts on a fresh stack, so per
  goroutine depth never exceeds the sequential depth, and a sequential
  overflow may complete in parallel (excluded by the condition on the
  sequential run). Out-of-memory is process-wide: up to B live stacks and
  concurrent allocation can exhaust memory the sequential run would not.
- *Residual exposure.* A discarded task's work until its next poll; a
  discarded task's diverging pure cleanup keeps its goroutine until program exit.

**Discard runtime contract (extension of Task 8).** Discard unwinds with
a distinct sentinel panic (`waxwingDiscard`), which `handle` re-panics as
any non-owned panic; `waxwingCleanup` treats it as a pending non-defect:
it runs the remaining cleanup, records no cause for it and re-panics the
sentinel, even if a cleanup raised a defect meanwhile; those causes are
dropped with the discarded outcome. A root records `X` for any panic it
recovers while its task is flagged, sentinel or defect; no task identity
is needed in the sentinel. Dropping loses nothing the sequential run has.
A task is flagged only when a failure was recorded to its left, or to the
left of one of its ancestors. In the sequential run that failure unwinds
the enclosing `par` before this task's expression starts, so neither its
work nor its cleanup defects exist there. The selected failure keeps all
its causes (D §3). CF001 does not report dropped causes on any channel,
because whether a discarded task reaches a failing cleanup depends on
scheduling. FX002 decides whether discarded or cancelled siblings get
secondary report lines. A per-task cleanup depth, owned by the task's
goroutine, masks its polls while deferred expressions run, and children
forked inside that cleanup are shielded (above), so each cleanup runs
exactly once and, unless the process exits first (unobservable: a discarded task's cleanup is pure), to completion (O6, C4).

**Failure selection (leftmost).** Let i be the least index whose child
did not produce a value. The parent waits until children 1..i-1 recorded
values and child i recorded its outcome, then re-raises child i's
outcome. If some child j < i diverges, the construct diverges, as
sequentially (eager discard never stops a child left of a failure).

Why rows are restricted: discarding equals never having run only if the
discarded child did nothing observable, which holds for Fail-only rows
(R0) with Shareable captures (B3). Other labels' effects already happened.

```
// hypothetical
par let a = spin(), b = crash("x");   // sequential and CF001: diverge
par let a = crash("x"), b = spin();   // both report crash: x; b discarded
handle { par let a = fail(E1), b = grow(nil); 0 } { fail(e: E1) => 1 }
                                      // b discarded and stopped at a call
```

Effectful children (FX002) cannot be sequentially equivalent; to settle
there: leftmost-among-finished versus first-to-finish, secondary report
lines (a format change), and dropping versus forbidding extra aborts.

## 7. Cancellation as a future block-exit reason

Spec §3 lists four exits (normal, typed abort, recoverable defect, future
continuation discard). Proposed fifth: **cancellation**, requested by a
parent scope (sibling failure, timeout) and delivered only at
cancellation points. CF001's discard (§6) is its restricted precursor.

- **C1 Delivery.** Cooperative only (Go cannot interrupt a goroutine):
  function entry, operation performs, `with`/`handle` entry. Foreign
  calls (I001) are not interruptible unless adapters poll. Clauses run
  in the handler-site context (B2), so FX002 must find the task identity
  outside the context list (e.g. a separate task parameter). CF001 may
  keep it in the context list only because Fail-only children never run a
  parent-installed clause; FX002 supersedes that placement.
- **C2 Not a failure.** Not a typed failure, not caught by `handle`, not
  a report cause; a pending abort or defect is kept. A defect raised by
  cleanup during cancellation becomes the task's outcome; it is reported
  only if that task is selected (secondary lines: FX002 decision).
- **C3 Exactly-once cleanup**, whatever the exit reason. **C4** Cleanup
  is shielded by default; an explicit `shield { … }` is optional, later.
- **C5 Suspending cleanup.** Cleanup that waits can deadlock on a task
  waiting for this task's scope. Proposed: cleanup may wait only on tasks
  it starts itself; static (from rows, at check time) or runtime check is
  an FX002 decision.
- **C6 Continuation ownership (new, not OCaml precedent).** Affine,
  owned by the capturing clause activation: resumed once or discarded
  once; discard is the "continuation discard" exit and runs the captured
  frames' cleanup. Beyond OCaml 5 (where resume/discontinue is the
  programmer's obligation), the runtime discards an unresumed
  continuation when its owner exits or its task is cancelled; obligation:
  each captured activation's cleanup runs exactly once (PROPOSED PROOF).
  Not Shareable; never crosses tasks.
- **C7 Unresolved.** Multi-shot resumption of continuations containing
  `defer` remains unresolved (spec §3), including whether cleanup runs per
  resumption.

## 8. Information that must survive checking

Row erasure (Task 6) can remain. What future work needs, and where:

| Need | Where | Erasure impact |
|---|---|---|
| R0 restrictions (`par` Fail-only, `defer` Fail-free) | Check, after solving the declaration | none |
| B3 Shareability | Check, from types, handler clause rows and a declaration attribute (hypothetical `local effect Counter`); `EffectInfo` may carry it for runtime assertions | none: derived from types and declarations |
| C5 waiting in cleanup | Check, from rows | none |
| CF001 discard polls | runtime: `par` joins the ctx-mode triggers; task record on context nodes | additive field in `waxwingCtx`; spec §4 trigger change (§10) |
| FX002 blocking on goroutines | none: goroutines are stackful, so blocking needs no CPS | none |
| General resume (`ctl`): which code may capture | post-specialization analysis over the IR call graph and function-value flow, keyed by an `EffectInfo` control kind | conservative merging per `FunType`; if too imprecise, a suspension bit on IR arrow types (bounded row-aware re-specialization, already named in spec §4) |

Only CPS-based general resume needing that bit in keys is a genuine
incompatibility, and it is already recorded (decision 1 revision).

## 9. Recommendation: CF001

**Subset.** One built-in structured fork-join item (hypothetical `par let
x1 = e1, …, xn = en;`) whose children are Fail-only under R0 and capture
only Shareable values (B3), with conditional sequential equivalence and
leftmost selection (§6), bounded live tasks with inline fallback, a
root for every child (inline included), eager discard, propagated to nested tasks and stopped at function-entry and join polls with the discard runtime contract (§6), abort
transfer at the join (B1, B4), and the defect runtime emitted with `par`. No shared mutable state, no effectful children, no user laws.

**Core semantics sketch.** The parent blocks at `par` with outcomes
`o1..on`, each ⊥ (running), `V v`, `A (m, p)` (abort to marker m) or
`D cs` (defect), or `X` (discarded). Child k runs `ek` under its own
root (spawned, or inline after the spawns if over budget) with the
parent's context Γ for lookup and an empty unwind stack; its cleanup runs
inside it. When child j records `A` or `D`, every child k > j gets `X`
(stopping at its next poll; an unstarted inline child never starts).
Join: if all `ok = V vk`, bind and continue. If the least i with
`oi ∉ V` has `oi ∈ {A, D}` and `oj = V` for all j < i, re-raise `oi`
(abort: panic to m on the parent goroutine; defect: causes `cs`, then
parent cleanup causes). If the parent is itself discarded (and not in
cleanup), it abandons the join and unwinds. Otherwise wait. Within one
level `X` is never selected: a sibling discard reaches only indices >
some recorded failure, and overwriting their recorded outcomes is
harmless because they are unselectable; an ancestor discard reaches every
child but also abandons the parent's join, so no selection happens.

**Per-guarantee contract.**
| Property | Assumptions | Compiler checks | Runtime left | Excluded programs |
|---|---|---|---|---|
| Type/effect soundness | spec §2 rows; R0 | R0 on children; B3 captures | child root; re-raise at join | children with non-Fail labels or open rigid/named tails (row-polymorphic callbacks) |
| Data-race freedom | FX001 has no mutable values (FX001-relative); immutable context; no shared lookup cache (§10) | B3 capture check | `go`/WaitGroup publication | Console or any service in children; non-Shareable captures (FX003) |
| Determinism | §6 condition (no Go fatal error in the sequential run, or in the process while the construct's goroutines are live) | as above | leftmost selection; discard polls; bounded tasks | as above |
| Deadlock freedom | each task waits only on its own children | none beyond nesting | join | none in CF001 (no other waits exist) |
| Cancellation safety | n/a: only pure discard, whose cleanup is unobservable | none | discard poll | (all cancellation is FX002) |

**Proof obligations.**
| # | Obligation | Status |
|---|---|---|
| O1 | Under FX001 (no mutable cells), Fail-only children with Shareable captures share no mutable state; the generated Go for them writes only goroutine-local locals and fresh allocations | PROPOSED PROOF (over the lowering contract) + TEST-ONLY (`-race` runs of the CF001 corpus); must be re-proved when FX003 adds cells |
| O2 | Boundary soundness: a child needs no operation handler (R0); every abort it raises targets a `handle` enclosing the `par`, live at the join | PROPOSED PROOF (typing; graded semantics if mechanized) |
| O3 | Branches sharing no mutable state behave as their sequential composition | PROPOSED PROOF (shape follows DPJ's noninterference argument; DPJ's theorem does not cover Waxwing's lowering, aborts or defects) |
| O4 | Conditional sequential equivalence with leftmost selection (§6) | PROPOSED PROOF (from O1-O3 and the discard argument) |
| O5 | Deadlock freedom: each task waits only on its own children (nested `par` included); the wait-for graph is a tree | PROPOSED PROOF (immediate) |
| O6 | Exactly-once cleanup per child activation, including discard unwinding; child cause order as sequential | PROPOSED PROOF (spec §3 per goroutine) + TEST-ONLY |
| O7 | Every recoverable panic on a child goroutine is recovered by its root | TEST-ONLY (injected crashes, guard panics, Go runtime panics) |
| O8 | Publication of Γ and outcomes: `WaitGroup.Done` synchronizes before the `Wait` it unblocks; the join primitive chosen must give the same publication edge (e.g. a channel send happens before the receive it unblocks) | ESTABLISHED (Go `sync` documentation); the `go`-statement rule: trusted platform guarantee, not re-verified here |
| O9 | Per construct, any mix of spawned and inline children yields the sequential outcome (eager discard reaches inline children; roots never raise) | PROPOSED PROOF + TEST-ONLY (budgets 0, 1, B; budget 1 with a spawned failing left child and an inline divergent right child must abort) |
| O10 | A discarded child stops at its next poll (function entry or join) outside cleanup; live goroutines never exceed B | TEST-ONLY (probes: `fib`, `grow`, `par let a = slow(), b = fail(E), c = grow(nil)`, nested `par let a = fail(E), b = { par let c = grow(nil), d = 1; c }`, `par` inside `defer` under discard, discard in a loop) |
| O11 | Fatal-error exposure beyond the sequential run is limited to process-wide out-of-memory (§6 *Stack and memory*) | TEST-ONLY (documented limitation) |

Oracle: plan Task 10's interpreter running `par` sequentially, diffed
against runs with injected yields and budgets 0, 1 and B.

Not guaranteed: anything about effectful children; cancellation beyond
discard; lawful reductions (CF002 candidate: built-in `Int` sum first).

## 10. Handoff

**Settle before concurrency (FX002), mutable state (FX003), resumable
handlers (FX006):**
1. R0, for `defer` (ruled; strictness pending user confirmation) and `par`.
2. B1 (lookup inherited, unwinding local, abort transfer at join).
3. B3 as a transitive property of handler types plus the capture check:
   before FX003, which cannot land without it.
4. Lookup caches (FX005) must be per-task or immutable at publication; no
   write into a node reachable from another goroutine. Before FX002.
5. Law-establishment policy (§4.7): before C001/STD001 publish `Monoid`.
6. Cancellation as an exit reason and C1-C4: before FX002 and general
   resume (discard and cancellation share the cleanup path).
7. Continuation ownership C6: before general resume.
8. Whether effectful parallelism promises more than race freedom
   (recommend: no determinism promise; leftmost selection by default).

**Can wait:** the budget B; join primitive; Console line atomicity;
chunking of large `par`; goroutine- versus CPS-backed one-shot resume.

**Necessary changes to the existing design** (spec text, not code):
1. §2 `defer` rule: adopt R0 (row tails). Example: `after` in §5.
2. §3 "Block exits": make the list open and name cancellation. Example:
   `par let a = { let c = open(); defer close(c); use(c) }, b =
   fail(Timeout);` (FX002-era) must run `close(c)` when `a` is cancelled;
   that exit is not an abort, defect or discard.
3. Direction decision 4 and resume-readiness: add B1. Example: §5's
   `handle { par let a = load(1), … }` without B1.
4. §3 "Cleanup failures" and §1's `with pure` sentence: §11's wording.
5. §4 "Uniform `ctx`" (D:485-491): `par` joins the trigger list, and in
   that mode every function entry polls the task flag. Example: the pure
   `fib` above, effect-free today and emitted without `ctx`, would take
   `ctx *waxwingCtx` in every function and pay a nil-checked pointer load
   plus an atomic load per call (to be measured, as plan Task 1 did for
   lookup). Programs without `par` are unchanged, so plan test 13 and the
   byte-identical snapshots still hold. Rejected alternative: polls only at
   `par`, join and operation boundaries cannot stop a pure divergent child.
   Lowering invariant (with a test): any future lowering that turns (tail)
   recursion or another construct into a Go loop keeps a poll in each
   iteration.
6. Task 8 runtime contract: the discard sentinel, its non-defect
   treatment in `waxwingCleanup` (cleanup defects of a discarded task are dropped, see §6; D §3's rejection of "dropping the cleanup failure" is scoped to tasks whose outcome can be selected), poll masking during cleanup, and
   discard propagation to nested tasks with shielding of tasks forked in
   cleanup (§6).
No change is needed to row erasure, markers, the `defer`-must-not-fail
decision, or (for CF001) the report format, beyond change 6's scoping of D §3; FX002 may change the format
if sibling defects become secondary lines.

**Compatibility of Tasks 6-8.** Task 6: compatible (§8). Task 7:
compatible; immutable nodes make inherited lookup race-free; the child
root, re-raise and the task field on context nodes are additive, but the
ctx-mode trigger and function-entry polls change §4 (change 5). Task 8:
compatible at runtime after change 6 (per-activation cleanup state is
goroutine-safe; `main`'s report needs the child root to forward defects);
its `defer` check needs R0, as ruled. None of
Tasks 6-8 needs to be undone.

## 11. Documentation audit (corrections for the controller to apply)

Status: items 1-7 applied by the controller 2026-10-09 (spec D, progress);
the ID inconsistency was resolved by pre-flight ruling F14: general resume
is FX006 in the spec and plan; BACKLOG FX004 keeps the Task 5 row.

Seven over-promises (file:line, quoted, then proposed wording), plus one
ID inconsistency. D = docs/plans/2026-10-09-effects-design.md.

1. D:46-47 "… on the same evidence model." → "… building on the
   evidence model, subject to task-boundary rules under review (CF001)."
2. D:49-51 "specified to remain sound under future captured
   continuations." → "intended to remain sound under future one-shot
   continuations; multi-shot continuations containing `defer` are
   unresolved (section 3)."
3. D:75-77 "Defects are uncatchable; cleanup still runs." → "Recoverable
   defects are uncatchable; cleanup still runs …; Go fatal errors (stack
   exhaustion, out of memory) skip cleanup (section 3)."
4. D:125 "Omission is not a promise of purity; `with pure` is." →
   "… not a promise of an empty effect row; `with pure` is. It promises
   neither termination nor freedom from `crash` (section 3)."
5. D:341-343 "exits for exactly one of four reasons" → "exits for exactly
   one reason: normal completion, typed abort or recoverable defect in
   FX001; continuation discard and cancellation are future reasons. …;
   a Go fatal error is not an exit and runs no cleanup."
6. D:349-358 "always reaches its own `handle`, and no typed error is ever
   lost or converted … so nothing recoverable is lost" → "reaches its own
   `handle` if every deferred expression run on the way completes
   normally; no typed cleanup failure can replace, drop or convert it. …
   If cleanup raises a recoverable defect, the pending abort stops being
   recoverable and heads the report; if cleanup diverges, it is never
   delivered."
7. docs/progress.md:3034-3035 "a pending typed abort always reaches its
   `handle`" → "… reaches its `handle` unless a cleanup on the way raises
   a defect (the abort then heads the report) or diverges."

Items 3-4 must also reach plan Task 12's language section. Checked and
accurate: effects-plan.md:526-530 and :657-658; docs/findings.md:371-375;
docs/next-session.md:17-18; D:627 ("exactly once" for argument effects).

ID inconsistency: BACKLOG.md:75 uses FX004 for the finished Task 5
validation gaps; D:672-673, D:779 and effects-plan.md:661-662 reserve
FX004 for general resume. Give general resume a fresh ID (e.g. FX006) or
rename the Task 5 row; the user chooses.

## 12. References

Verified in this session: title, authors, venue, year, and the cited
claim against the abstract or a search summary (full texts could not be
fetched). Re-read theorem wording in full text before writing any proof.

- Lucassen, Gifford. Polymorphic effect systems. POPL 1988, 47-57.
- Bocchino et al. A type and effect system for Deterministic Parallel Java. OOPSLA 2009, 97-116.
- Kuper, Newton. LVars: lattice-based data structures for deterministic parallelism. FHPC 2013.
- Kuper, Turon, Krishnaswami, Newton. Freeze after writing: quasi-deterministic parallel programming with LVars. POPL 2014, 257-270.
- Marlow, Brandy, Coens, Purdy. There is no fork: an abstraction for efficient, concurrent, and concise data access. ICFP 2014, 325-337.
- Kammar, Plotkin. Algebraic foundations for effect-dependent optimisations. POPL 2012, 349-360.
- Katsumata. Parametric effect monads and semantics of effect systems. POPL 2014, 633-645.
- Atkey. Parameterised notions of computation. JFP 19(3-4), 2009, 335-376.
- Jung, Jourdan, Krebbers, Dreyer. RustBelt: securing the foundations of the Rust programming language. POPL 2018.
- Leijen. Structured asynchrony with algebraic effects. TyDe 2017 (MSR-TR-2017-21).
- Sivaramakrishnan et al. Retrofitting effect handlers onto OCaml. PLDI 2021. One-shot continuations that must be resumed or explicitly discontinued: from an OCaml project announcement, not re-verified in the paper or manual.
- Ahman, Pretnar. Asynchronous effects. PACMPL 5 (POPL 2021), article 24.
- Shapiro, Preguiça, Baquero, Zawirski. Conflict-free replicated data types. SSS 2011, LNCS 6976, 386-400.
- Go `sync.WaitGroup` documentation (pkg.go.dev/sync), fetched 2026-10-09: "a call to Done 'synchronizes before' the return of any Wait call that it unblocks." The Go memory model page (go.dev/ref/mem) could not be fetched: unverified.

## Review response (2026-10-09)

Round 1 (review-cf001-result.md): C1, I1-I8 and M1-M10 applied (see
§6, R0, B3, §4, §9, §10). Round 2 (rereview-cf001-result.md): N1 roots
for every child and eager discard; N2 change 5; N3 discard contract and
change 6; R0 aligned with the `defer` ruling; M-a to M-d applied.
Round 3 (rereview2-cf001-result.md): P1 discard propagates to live
descendants, tasks forked by discarded tasks start discarded, joins are
poll points, a discarded parent abandons its join, `X` invariant restated
across levels, nested probe in O10, change 6 extended; P2 condition over
both runs, out-of-memory process-wide; P3 loop-lowering poll invariant
(change 5); P4 tasks forked in cleanup shielded; P5 roots see the
sentinel and record `X` for anything recovered while flagged. Declined in
all rounds: none.

Round 4 (re-review 3 minors N1-N5): applied verbatim from the re-review.
