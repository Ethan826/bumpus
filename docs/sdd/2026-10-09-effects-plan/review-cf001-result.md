# Review: CF001 concurrency-foundations design (docs/plans/2026-10-09-concurrency-foundations-design.md)

Reviewer: adversarial review, read-only. Line numbers refer to the document under review ("L") unless prefixed (D = docs/plans/2026-10-09-effects-design.md). Checked against cc-requirements.md, spec §2-§4, and shipped runtime (src/Format/Go/Context.purs, Handle.purs, Cleanup.purs, Features/Check/Defer.purs; Task 8 is committed as 041cb31).

## Requirements coverage

| Requirement (cc-requirements.md) | Status | Where / gap |
|---|---|---|
| Small set of primary sources | ✅ | §12, 12 sources |
| Regions / read-write effects, ownership / linear-affine capabilities | ✅ | L82-83, L91-101 |
| Applicative independence; laws alone insufficient | ✅ | L84, L102-105 |
| Commutative effects | ✅ | L85, L106-109 |
| Graded / indexed monads for dependencies, resource access, permitted composition | ❌ (partial) | L86, L110-111 assess graded monads in one line; indexed/parameterised monads (resource-state protocols, "permitted composition") are not assessed at all (Important I7) |
| Lattice/LVars, which laws support which guarantee | ✅ | L114-137 (precision issues: M2, M10) |
| How laws are established; instance ≠ proof | ✅ (partial) | L139-149; tiers are not mapped onto each §4.6 row; policy overbroad (I6) |
| Structured concurrency, task-local state, shared capabilities | ✅ | L87, L112, B3 L188-203 |
| Separate the five properties | ✅ | L52-76 |
| Per proposed guarantee: assumptions, compiler checks, runtime left, excluded programs | ❌ (partial) | Done per *approach* (L80-87) but not per *CF001 guarantee*; O-table (L338-350) gives only status (I7) |
| Small defensible initial subset | ✅ | §9 |
| 1. Tasks 6-7 erasure, immutable ctx, dynamic handlers, targeted aborts; immutability ≠ safe sharing | ✅ | L32-40, L35 |
| 2. Task-boundary rules: inheritance, sharing/transfer, child failures; no inherited parent unwinding | ✅ | B1-B5 L157-215 (soundness gaps I2, I3) |
| 3. `pure` permits divergence/crash; equivalence + failure selection | ✅ (with Critical C1) | §6 L217-261 |
| 4. Task 8 typed-abort vs defect; audit over-promises | ✅ | L42-50, §11 |
| 5. Cancellation as exit; exactly-once, shielding, suspending cleanup, continuation ownership; multi-shot unresolved | ✅ | §7 L263-296 (I5, M8) |
| 6. Information surviving checking / IR metadata | ✅ | §8 (M6) |
| Handoff: settle-before list | ✅ | L364-377 (I8) |
| Handoff: can wait | ✅ (one wrong entry) | L379-382: goroutine-per-child (C1) and cached lookup (I8) cannot simply wait |
| Handoff: necessary changes with concrete examples | ✅ | L384-398 |
| Handoff: core semantics + labeled proof obligations | ✅ | L327-350 (labels: I4) |
| Do not undo 6-8; extendability vs real incompatibility | ✅ | L400-407 (M4, M7) |

## Critical

**C1. L219-224, L248-255, L345, L379-381 — the sequential-equivalence claim (O4) is not achieved as stated; the exclusion of fatal errors is triggered by the parallel implementation itself.**
Problem: the equivalence excludes Go fatal errors (stack, memory) "outside the semantics today", and L379 leaves goroutine-per-child versus pool to the runtime. But the parallel program executes code the sequential program never runs and holds resources the sequential one never holds:
- Discarded right siblings are not stopped (L248). After an abort is caught, the parent continues indefinitely, so a discarded child runs "until they finish" (L251), which for a divergent child is the program's lifetime, not "before the program exits" (L254). Example: `handle { par let a = fail(E), b = grow(nil) } { fail(e: E) => … }` where `grow` allocates without bound. Sequentially `grow` never runs and the program terminates normally; under CF001 it ends in a fatal out-of-memory error. In a loop, every iteration leaks another goroutine.
- With goroutine-per-child, the canonical example `fib(n) = par let a = fib(n-1), b = fib(n-2); a + b` spawns O(fib(n)) live goroutines (parents block at joins and keep their stacks). Around n ≈ 30 that is gigabytes of goroutine stacks, so the canonical program dies of a fatal error the sequential program cannot hit.
- Stack depth differs in both directions: a child starts on a fresh goroutine stack, so a program that overflows sequentially (depth of parent plus child) may complete in parallel.
So "observably equal" holds only for runs in which no goroutine, including discarded ones, hits a fatal error. That precondition is not checkable and is violated by ordinary CF001 programs.
Why it matters: O4 is the headline guarantee, and under the stated freedom it is vacuous for the motivating workload.
Fix: (a) state O4 as a conditional refinement: "for every run in which no goroutine, discarded ones included, incurs a Go fatal error, the outcome equals the sequential outcome". Add a separate resource clause naming the extra exposure. (b) Make bounded live tasks part of CF001's contract, not a deferrable runtime choice: a child may run inline on the forking goroutine when the worker budget is exhausted, which sequential semantics permits. (c) Either require discarded children to stop at cheap polls (for example at child-reachable function entries, or a flag checked by the child root's nested `par`s), or document that a discarded divergent child keeps running for the program's lifetime and can turn a terminating program into a fatal one. Move this out of "can wait" (L379-382).

## Important

**I1. L233-238, L304, L318-320 — the Fail-only check, specified "as Task 8's `defer` rule … inspect labels", is unsound for row tails.**
Problem: Features/Check/Defer.purs inspects only the labels of the child's fresh row (`failures (Row labels _)`). A child whose effects reach it through a rigid ambient tail or a `...e` variable has no non-Fail labels. Example: `fn both(f: Int -> Int, g: Int -> Int) = { par let a = f(1), b = g(2); a + b }`; the callers pass Console-printing `f` and `g`. A labels-only check accepts it, and the prints become racy and nondeterministic. A flexible tail left open at the `par` can also gain labels after the item is checked (for example, a lambda parameter whose row is solved later).
Fix: specify that the check runs after solving, like `rejectDeferred`. The child row must be exactly Fail labels plus a tail that is empty after closing flexible holes. Reject any rigid or named row variable with its own diagnostic. Add the example above as a required rejection test.

**I2. L96, L188-194, L342, L396-398 — "Fail-only rows" stops implying "no shared mutable state" once FX003 exists; CF001's check is FX001-relative and the doc does not say so.**
Problem: a Fail-only child can capture a handler *value* from the parent and install it locally. Example: `let c = counter(0); par let a = with c { tick() }, b = with c { tick() };` gives each child the row `Fail…`/pure, because Counter is handled inside the child, yet both children mutate one cell. O1's argument ("FX001 values and handlers are immutable") and L96 ("Fail-only code already satisfies 'no mutable state reachable'") stop holding as soon as FX003 lands.
Fix: state O1 as FX001-relative. Make B3 part of CF001's check on the children's free variables (captured locals must be Shareable) from the start, or at least list "CF001 check must add the B3 capture check" as a hard prerequisite of FX003 in L368-369.

**I3. L182-194, L305, L368-369 — B2/B3 per-effect Shareability misses effects performed by clauses in their handler-site context.**
Problem: B2 runs inherited clauses on the child, in the handler-site context (D §3 "Clause context"). A clause's effects are discharged in that outer context and never appear in the child's row. Example (FX002/FX003 era): `with counter(0) { with logToCounter { par let a = log("x"), b = log("y"); } }`. Log is a non-`local` effect, so the child rows contain only Log and pass a per-effect attribute check, yet both clauses `tick()` the same counter concurrently. The "per-effect declaration attribute" (L194, L305) classifies labels, not handler instances, and handlers are selected dynamically.
Fix: make Shareability a property of handler *types*, derived transitively from the clause row: `Handler(L with R)` is Shareable only if every label in R is Shareable and R's tail is closed or Shareable-bounded. Alternatively, the `par` check must cover the rows of every handler reachable in the inherited context, which erasure and dynamic selection make impossible in general. Record this as handoff item 2's actual content.

**I4. L344, L323-325, L349, L477 — ESTABLISHED labels overclaim.**
- O3 "ESTABLISHED (DPJ, Bocchino et al. 2009) given O1": DPJ's theorem is for DPJ's calculus, with region effects and a compiler-checked disjointness rule. It covers neither Waxwing's lowering nor failure/divergence selection, and DPJ has no typed-abort or defect semantics to compare. With O1 (no shared mutable state at all), value equivalence is a direct consequence to prove for Waxwing, not an instance of DPJ. L323's "established theory applies with no new type machinery" repeats the overclaim. Fix: relabel O3 PROPOSED PROOF (shape follows DPJ) and drop "established" from L323.
- O8 "ESTABLISHED (Go memory model)" while L477 says the Go memory model was "not verified here". Also, WaitGroup's synchronizes-before guarantee is stated in the `sync` package documentation, not on the memory-model page (only channels and `go` statements are there). Fix: verify, cite go.dev/ref/mem for `go`/channels and the `sync.WaitGroup` docs for Done/Wait, then keep ESTABLISHED. Otherwise mark it "trusted platform guarantee, unverified".

**I5. L87 (and L291) — citation error: OCaml 5 does not discontinue unused continuations.**
Problem: L87 says "OCaml 5 … one-shot continuations, unused ones discontinued". In OCaml 5, dropping a continuation leaks the resources of its captured frames; discontinuing is an explicit programmer obligation, and the paper and manual do not run finalisers for unresumed continuations. C6's rule (runtime discards unresumed continuations owned by a cancelled task) is a Waxwing proposal, not OCaml precedent.
Fix: L87: "one-shot continuations; resuming or discontinuing is the programmer's obligation, and dropped continuations leak their frames' cleanup". Present C6's automatic discard as new, with its own proof obligation.

**I6. L144-149, L125-132 — law-establishment policy is overbroad and not mapped per abstraction.**
Problem: "a user-asserted law may affect *which value* a program computes … never type soundness, data-race freedom, cleanup or report integrity" omits termination and deadlock. With user lattices, a non-monotone join or threshold sets that are not pairwise incompatible can block a threshold read forever, or release it nondeterministically. User combiners that `crash` also make failure selection shape-dependent. In addition, §4.6's six rows name laws but not which tier of §4.7 establishes each (only `Int` add is placed). The requirement asks how each law is established.
Fix: add "termination of threshold reads and which failure is reported" to what user laws may affect, or restrict LVar lattices to trusted built-ins. Add a "Established by" column to the §4.6 table, for example: monoid, built-in `Int` add = compiler restriction plus proof; user monoid = user obligation plus PBT001; LVar lattice = trusted built-in only.

**I7. L80-87, L110-111, L338-360 — two requirement gaps.**
(a) Indexed or parameterised monads (Atkey-style resource-state indices, for "resource access, and permitted composition") are not assessed. Add a row and a verdict, even if the verdict is "defer: needs K001; typestate for capabilities is subsumed by affine transfer (B3) later".
(b) "For each proposed guarantee, explain its assumptions, what the compiler checks, what runtime machinery remains, and which programs it excludes" is done per approach, not for CF001's actual guarantees. Add a table for CF001 with one row per property (type/effect soundness, race freedom, determinism, deadlock freedom, cancellation safety: N/A) and columns assumptions / compiler check / runtime / excluded programs. The excluded programs include effectful children, row-polymorphic callbacks (I1) and Console in children.

**I8. L158-160, L382, L402-403 — "cached lookup (FX005)" is listed as can-wait, but B1's race-freedom depends on it.**
Problem: B1 and the Task 7 compatibility claim rest on context nodes never being mutated after publication. D:507-508 names a cached index as a follow-up. A cache written into shared nodes, or into any structure reachable from Γ, introduces data races on the lookup path every child uses.
Fix: move this to "settle before FX002": "lookup caches must be per-task or immutable-at-publication; no write into a node reachable from another goroutine".

## Minor

- **M1. L346** O5 says "children wait on nothing", which is false with nested `par` (Fail-only children may contain `par`). The tree claim still holds; reword to "each task waits only on its own children".
- **M2. L85, L117-118** Kammar & Plotkin give *sufficient* (soundness) conditions; "valid exactly when" overstates. Use "sound when". LVars FHPC 2013 uses threshold *sets* of pairwise-incompatible elements; "activation sets" is the later generalization (POPL 2014 / Kuper's thesis). Attribute it accordingly.
- **M3. L10-12, L38-39, L47-49, L404-405** Task 8 is committed (041cb31). Its runtime matches the description (local `waxwingCleanups` slice per block, `recover` in `waxwingCleanup`, one `waxwingReport` in `main`). Drop the "to be reconciled" hedges and cite the commit.
- **M4. L39, L405-406** `waxwingReport` and the defect runtime are emitted only when `usesDefects` (Cleanup.purs). With `par`, the child root must forward panics to a `main` that may have no wrapper. Without one, a re-panicked Go runtime panic prints Go's own trace (goroutine IDs, and a "[recovered]" annotation on re-panic), so stderr differs from the sequential run. Fix: any program using `par` emits the defect runtime, and child roots forward a `waxwingDefect` built with `waxwingCauses`.
- **M5. §11 items 1 and 6** Item 6 quotes D:349-354, but the over-promise "so nothing recoverable is lost" is at D:355-356; extend the range to D:349-358 so the replacement covers it. Item 1's proposed wording writes an unapproved CF001 rule into approved spec decision text; make it conditional ("subject to task-boundary rules under review (CF001)"). Items 2-5 and 7 are real and correctly worded. Spot-check grep ("always", "guarantee", "never lost", "exactly once", "cleanup runs") of D, the plan, findings, next-session, progress and the direction docs found no further over-promise. D:627 "exactly once" concerns argument evaluation and is accurate. The plan Task 12 language section (not yet written) must carry items 3-4.
- **M6. L306 vs L284-287** "no suspension analysis" conflicts with C5's possible static check (which code may wait inside cleanup). Say: check-time only, from rows, so no IR metadata is needed.
- **M7. L396-398** "No change … to the defect report format" holds for CF001 only; L257-261 leaves open appending secondary child defects in FX002, which would change the format. Qualify it.
- **M8. L274-277** C2 leaves out: a defect raised by cleanup while a cancellation unwinds (is it reported, and with what first cause?), and the fate of a cancelled child's defect under the parent's selection policy.
- **M9. L127-129** "Shared accumulator, read only after join" also needs per-update atomicity (runtime) and a total combiner. A crashing combiner makes the reported failure order-dependent. "Combiner pure and total" appears only on row 1.
- **M10. L172** the example comment `load: Int -> Row with Fail(DbError)` uses `Row` as a type name, which is confusing next to effect rows. Rename it (e.g. `Record`).

## Answers to the review questions (summary)

- Divergence vs crash: leftmost waiting matches sequential behavior for `spin` left / `crash` right, and for `crash` left / `spin` right, *except* that the discarded right child keeps running (C1).
- Fail-only is enough in FX001 *if* the tail is closed after solving (I1): Fail is handled only by lexical `handle`, whose clause runs on the parent after recovery (Handle.purs), and any `with`-installed handler value inside a child has its clause row unified into the child's row. It is not enough once FX003 handler values exist (I2), or for effectful children with handler-site clause effects (I3).
- Abort relay is sound. Markers are fresh heap pointers compared by identity (Context.purs `waxwingOwns`), immutable and published before `go`. The target `handle` is on the parent stack below the join, also when `par` sits in a `with` clause, because clauses resume immediately. Cleanup order equals sequential order, since Fail-only children's cleanup is unobservable except through outcomes, and the parent's intervening blocks run `waxwingCleanup` with the same pending value.
- Race/determinism/deadlock claims missing assumptions: O1 (FX001-only; I2), O3/O8 (I4), O5 (M1), §4.7 (I6), B1 (cache immutability; I8).

## Verdict

**Accept with fixes.** The design direction is sound and well grounded in the shipped runtime: lookup is inherited, unwinding stays local, aborts are relayed at the join, and selection is leftmost. Before user review, restate O4 and make bounded tasks and the discarded-child policy part of CF001 (C1), and apply I1-I8. None of these require rework of the overall structure.
