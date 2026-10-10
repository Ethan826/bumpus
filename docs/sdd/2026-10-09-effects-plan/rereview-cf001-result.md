# Re-review: CF001 design, fix round (d11e0a3..ceb979d)

Line numbers ("L") refer to docs/plans/2026-10-09-concurrency-foundations-design.md at HEAD (502 lines). D = docs/plans/2026-10-09-effects-design.md. Read-only; only the fix diff and the resulting text were inspected, plus D §4 "Uniform ctx" (D:485-498) and the working-tree Features/Check/Defer.purs, for the R0 comparison.

### Finding Verdicts

| Id | Verdict | Evidence |
|---|---|---|
| C1 | ADDRESSED (with new problems N1, N3) | L217-223: equivalence is now conditional on no fatal error in any goroutine, discarded children included. L225-240: bounded live tasks with inline fallback, the stack-depth caveat, and discard polls. L327-333: these are in the §9 subset. O9-O11 at L367-369. "Goroutine-per-child" was removed from can-wait (L395-397). |
| I1 | ADDRESSED | L129-150: R0 judges the expression's own row after solving. A rigid ambient or named tail is rejected, and the meta tail closes to empty. Both counter-examples (`both`, `after`) are required rejection tests. Applied to `par` and `defer` (L315, L382, L400). |
| I2 | ADDRESSED | L75 and L359: O1 is FX001-relative and must be re-proved for FX003. L196-200: the capture check is part of CF001 and a hard prerequisite of FX003. Handoff 3 is at L384-385. |
| I3 | ADDRESSED | L179-198: Shareability is a transitive property of handler types, derived from the clause row, with the `logToCounter` example and the rule that rejects it. Handoff 3 is at L384. (The alternative "Shareable-bounded tail" at L182-183 assumes bounded row quantification, which does not exist; see M-a.) |
| I4 | ADDRESSED | L361: O3 is PROPOSED PROOF with the DPJ scope caveat. "Established theory applies" is gone. L366: O8 is split into WaitGroup (ESTABLISHED, cited and fetched at L486) and the `go` statement (trusted, unverified). |
| I5 | ADDRESSED | L71, L296-304 (C6 marked "new, not OCaml precedent", with its own PROPOSED PROOF), L483 (source caveat). |
| I6 | ADDRESSED | L97-104: "Established by" column. L115-121: the policy now covers failure choice and termination, and blocking lattices are trusted built-ins only. |
| I7 | ADDRESSED | (a) L70 and L83-85: 4.5b Atkey, verdict defer. (b) L345-353: per-guarantee table with assumptions, compiler checks, runtime and excluded programs. |
| I8 | ADDRESSED | Handoff 4 at L386-387. The data-race row assumption is at L350. It was removed from can-wait. |
| M1 | ADDRESSED | L352, L363 |
| M2 | ADDRESSED | L68 "sufficient conditions"; L89-93 threshold sets, with activation sets attributed to 2014 |
| M3 | ADDRESSED | L10-11, L33 cite 041cb31 (a new, legitimate hedge on the *defer fix* remains at L11-12, L147-150) |
| M4 | ADDRESSED | L207-209 |
| M5 | ADDRESSED | L425-427 (conditional), L444 (D:349-358), L458 (Task 12 note) |
| M6 | ADDRESSED | L294, L317 |
| M7 | ADDRESSED | L408-410, L264 |
| M8 | ADDRESSED | L282-286 |
| M9 | ADDRESSED | L99-101 |
| M10 | ADDRESSED | L166 |

**R0 against the controller's Task 8 ruling.** The two agree on substance. Both judge the expression's own row after the function's constraints settle, never unify that row's tail with the enclosing row, reject a remaining `Fail` label, reject a tail resolved to the rigid ambient row or a named `...e`, and close an unsolved meta tail to empty (L131-136). They differ precisely in three places:
1. Consumption. The ruling consumes the deferred row's labels into the enclosing row at the item, with a fresh tail, and consumes labels that arrive later when the deferrals are settled. R0 (L133, L138) says only "excluding the equation that consumes it" and "Restricted rows are then consumed by the closed-row coercion of spec §2". That suggests a single consumption after judging, through the closed-row coercion. Reword to match: "its labels are consumed into the current row with a fresh tail; its tail is never unified with it".
2. Diagnostic. R0 does not give the new text for the rigid-tail case, `defer must not fail, but it may perform any effect of <r>`. It also does not give the corresponding `par` wording.
3. Status. L11-12, L147-150 and L382 still say "under review / to be reconciled". Once the user confirms the ruling, state it and drop the hedge. Until then the hedge is accurate.

### New Problems in the Fix

**Important**

- **N1. L228-229, L242-245, L339-343, O9 L367: inline execution of an over-budget child breaks equivalence and leftmost selection when that child diverges.** Discard is decided only at the join (L339-341: "mark children > i discarded"), and the join runs on the parent goroutine. An inline child occupies that goroutine. Example: budget exhausted, `par let a = fail(E), b = spin();` with a spawned and b inline. Sequentially, `a` aborts and `b` never runs. Under CF001 the parent is stuck in `b` and never reaches the join that would discard it, so the construct diverges instead of aborting. The same flaw makes discard late for spawned children. In `par let a = slow(), b = fail(E), c = grow(nil);`, `c` keeps allocating until `a` finishes, which is far more than L239-240's "residual exposure: work between discard and the next call". O9 ("inline yields the sequential outcome for that child") is true per child but not per construct, and the budget-0 tests cannot catch this. Fix:
  - Discard eagerly. When child j finishes with a non-value, its root sets the `discarded` flag of every sibling with index > j. This is always safe, because the selected index is at most j.
  - Give an inline child its own root wrapper and task record. It then records its outcome instead of raising it, which leftmost selection also needs when an inline k aborts while a spawned j < k later crashes, and it can be discarded.
  - Amend the core-semantics sketch and O9, and add a test: budget 1 with a spawned failing left child and an inline divergent right child.
- **N2. L235-238, L318, L408-417: forcing ctx mode for `par` and adding a per-function-entry poll changes shipped design contracts, but neither change is flagged.**
  - D §4 "Uniform ctx" (D:485-491) makes the mode depend only on operations, handlers, `fail`, `with` and `handle` in the emitted IR. A pure program with `par` (the canonical `fib`) would now thread `ctx` everywhere and poll at every function entry, including code that never runs in a child. That changes D §4's trigger list, plan test 13 and the "runtime stays small" claim.
  - §10's "Necessary changes" lists neither change. L410-411 mentions only "one additive field", and the Task 7 compatibility note (L413-415) mentions neither the poll nor the mode change.
  - The design also contradicts itself without saying so. C1 (L277-278) says task identity must live outside the context list, because clauses run in the handler-site context. CF001 puts it in the context list. That is sound only because Fail-only children never run a parent-installed clause, and the document does not say this.
  - Fix: add "§4 Uniform ctx: `par` forces ctx mode; function entry polls" to the necessary changes, with the cost. Either justify the context-node record by the Fail-only argument and note that FX002 supersedes it, or adopt the separate task parameter now.
- **N3. L238-239, O6 L364, C3/C4 L287-291, L415-417: discard unwinding interacts with Task 8's cleanup runtime, and the document does not address this.** The discard unwind needs a new panic kind:
  - `handle` must not catch it.
  - Task 8's `waxwingCleanup` (`recover` in each cleanup) must treat it as a pending non-defect, not as a defect cause.
  - Polls inside deferred expressions must not fire again while the child unwinds. Otherwise cleanup is interrupted part-way, which contradicts O6's "exactly once, including discard unwinding" and C4's "shielded by default".

  The outcome is ignored, so a Fail-only child's cleanup is hard to observe today. The claim is still stated, and Task 8 is called "compatible at runtime" without this change. Fix: specify the discard sentinel, the cleanup classification change and the no-repoll-in-cleanup rule, and list them under Task 8 compatibility.

**Minor**

- **M-a. L182-183:** "R's tail … itself Shareable-bounded" presupposes bounded row variables, which are neither proposed nor available in FX001. Say "closed (R0-style); bounded tails are a later alternative needing row constraints", matching R0's own deferral at L136-138.
- **M-b. L232-234:** "never the reverse" holds per goroutine. However, B spawned children with deep stacks add aggregate stack memory, so out of memory can occur where the sequential run does not. The condition at L217 covers this, but the bullet reads as a guarantee. Qualify it.
- **M-c. L238:** "one load and branch" is really a nil-checked pointer load plus an atomic load. Minor cost wording.
- **M-d.** R0's `par` diagnostic and the ruling's `defer` diagnostic text are not specified (see the R0 comparison).

ESTABLISHED labels. Two remain: L107 (`Int` `(+,0)` wraps modulo 2^32, confirmed at docs/language.md:143) and O8 L366 (WaitGroup, fetched source at L486). Both are warranted, and the unverified `go`-statement rule is correctly labeled trusted.

Boundedness: the document stays bounded. The non-goals (L21-23) hold, the syntax is labeled hypothetical, `shield` is "optional and later", and 4.5b, LVars and user laws are deferred. The recommended subset has grown runtime machinery (polls, task records, budget). It is justified by C1, but N2's cost should be stated so the user can weigh it. No speculative feature is presented as recommended.

### Verdict

**Accept with fixes.** All 19 findings are addressed. Before user review, fix N1 (eager discard plus a root wrapper for inline children) and flag N2 and N3 as necessary changes to D §4 and to the Task 8 runtime. Align R0's consumption wording with the ruling once it is confirmed.
