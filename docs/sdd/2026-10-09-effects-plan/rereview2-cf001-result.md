# Re-review 2: CF001 design, fix round (ceb979d..a8052df)

"L" line numbers refer to docs/plans/2026-10-09-concurrency-foundations-design.md at HEAD (518 lines). I inspected only the fix diff and the resulting text. I ran nothing.

### Finding Verdicts

| Id | Verdict | Evidence |
|---|---|---|
| N1 | ADDRESSED for a single `par` level; nested `par` has a gap (see P1) | L229-232 give every child, inline ones included, a root that records its outcome and never raises it. L233-238 add eager discard right of a recorded failure, and the `fail`/`spin` example now aborts. The sketch has `X` and per-record discard (L345-355). O9 is now per construct, with the budget-1 spawned-fail/inline-diverge test (L378). O10 has the `slow`/`fail`/`grow` probe (L379). |
| N2 | ADDRESSED | Change 5 (L417-424) covers the trigger, polls, the `fib` example, the cost, the unchanged non-`par` programs and snapshots, and the rejected alternative. The Task 7 note is at L431-436. C1 (L294-296) justifies the context-list placement by the Fail-only argument and says FX002 supersedes it. §8 row updated. |
| N3 | ADDRESSED | L252-259 define the `waxwingDiscard` sentinel: `handle` re-panics it, `waxwingCleanup` treats it as a pending non-defect, and a goroutine-owned cleanup depth masks polls. L239-242 and change 6 (L425-426) state the same, and the Task 8 note (L436-440) makes compatibility conditional on change 6. |
| R0 alignment | ADDRESSED | L122-136 match the ruling point for point: the expression gets its own row with a fresh meta tail; its labels are consumed into the current row with a fresh tail and its tail is never unified with it; the check runs after the function's constraints settle, and late labels are consumed then; a remaining forbidden label is rejected; a rigid ambient `...` or named `...e` tail is rejected; a meta tail closes to empty. The two `defer` texts appear verbatim, and the `par` texts are marked hypothetical. Strict checking versus a lacks constraint is marked pending user confirmation (L134-135, L392). The status hedge is replaced (L10, L392). |
| M-a | ADDRESSED | L179-180 |
| M-b | ADDRESSED | L243-247 |
| M-c | ADDRESSED | L239-240 |
| M-d | ADDRESSED | L130-134 |

Specific questions:

- **Eager discard versus leftmost selection, with a left sibling still running.** These are consistent. Suppose j fails while some i < j is still running:
  - If i later fails, it discards every k > i, including j's already recorded outcome, and selection takes i. The sequential run gives the same result.
  - If i diverges, the join waits forever, and the sequential run diverges too (L261-264).
  - If i returns a value, j is selected.

  Discard only reaches indices greater than a recorded failure, so the least non-value index is never `X` within one level. Overwriting a recorded `V` or `D` of some k > j with `X` is harmless. The sketch should still say that "gets `X`" does not replace an already recorded `A` or `D` of a child that is itself selectable. It cannot be, because some failure to its left exists, but the proof of O4 should state this.
- **Necessary changes 5 and 6** are concrete and correctly scoped. Change 5 names the D section, gives an example, states the cost and the measurement plan, gives the reason for the rejected alternative, and confirms the non-`par` invariants still hold. Change 6 names the three runtime additions. P1 below adds one item to change 6, or a change 7.

### New Problems

**Important**

- **P1. Discard does not reach nested `par` (L229-238, L252-259, L345-355).** The round-1 text said the task record is "copied into nodes installed below it". That phrase is gone. Every child, including a grandchild, now has its own task record, and polls read only that record. Example: `par let a = fail(E), b = { par let c = grow(nil), d = 1; c };`. Here `b` is discarded, but:
  1. `b` is blocked at its own nested join, which is not a poll point.
  2. Its spawned or inline grandchild `c` polls only its own flag, which nothing sets.

  `c` allocates without bound and ends in an out-of-memory fatal error that the sequential run never reaches. This is the N1 failure one level down, and it contradicts the "residual exposure" bullet (L248-251) and O10. The fix must also amend the sketch:
  - Discard must propagate to descendants. Either the poll walks or caches the ancestor chain, or each task links to its parent's flag.
  - The join must also be a discard point.
  - Today the sketch can only stall a join. A child marked `X` by an ancestor's discard has no failure to its left, so "otherwise wait" blocks for ever, and L355's claim "`X` is never selected: only indices > some recorded failure" no longer holds across levels. A discarded parent must instead abandon its join and unwind.
  - The sentinel needs a task identity, or a root must unwind on any ancestor discard. Otherwise a grandchild's root records "discarded" and the parent never stops.

  Add a nested probe to O10 and add this item to change 6.
- **P2. The equivalence condition does not cover what the mechanism actually delivers (L213-221 versus L243-245).** The condition constrains only the parallel run, but L244-245 states that "a sequential overflow may complete in parallel". In that case the sequential outcome is a fatal error, which is outside the outcome set {value, abort, defect, divergence}. The equivalence claim ("under it, `par` has the observable outcome of the sequential evaluation") is then false. Fix it in one of two ways:
  - Require that neither run incurs a Go fatal error.
  - State a refinement: if the sequential run has no fatal error and the parallel run has none, the outcomes are equal.

  Also, "no spawned stack it adds incurs a Go fatal error" misattributes aggregate out-of-memory errors (L246-247), which belong to the process and not to any one stack. Write "no Go fatal error occurs in the process while any goroutine started by the construct is live".

**Minor**

- **P3. Loop assumption (L218-220).** "Waxwing has no loop construct" is true of the source today. The controller has verified that emitted Go contains only bounded runtime loops, so the assumption holds for current lowering. However, it is stated about the source, while the poll lives in the lowering. Add: "any future lowering that turns (tail) recursion or another construct into a Go loop must keep a poll in each iteration." List this under change 5 or as a lowering invariant with a test.
- **P4. Poll masking with nested `par` inside a deferred expression (L252-259).** A `par` with Fail-free children is legal inside `defer`. Its children's polls check their own task's depth, not the cleaning task's. This is harmless only once P1's ancestor propagation also respects the ancestor's cleanup mask. State that explicitly when fixing P1.
- **P5. Defects during discard (L255-257).** "re-panics the sentinel (a defect raised meanwhile is recorded … and ignored)". Say which panic the root receives when a cleanup defect occurs: the sentinel or the defect. The root must classify both as `X`.

### Verdict

**Accept with fixes.** N1-N3, R0 and M-a to M-d are all addressed. The eager-discard rule is consistent with leftmost selection within one level. Before user review:
1. Fix P1 (discard propagation through nested `par`, the join as a discard point, and the sketch's `X` invariant).
2. Fix P2 (the condition on both runs, and process-wide fatal errors).
3. Add P3's lowering invariant.

P4 and P5 are wording fixes.
