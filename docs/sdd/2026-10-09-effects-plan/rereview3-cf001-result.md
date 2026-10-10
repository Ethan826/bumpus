# Re-review 3: CF001 design, round-3 fixes (a8052df..29ce6a9)

"L" line numbers refer to docs/plans/2026-10-09-concurrency-foundations-design.md at HEAD (530 lines). "D" refers to docs/plans/2026-10-09-effects-design.md. I read the fix diff once and then the resulting text. I ran nothing.

### Finding Verdicts

| Id | Verdict | Evidence |
|---|---|---|
| P1 | ADDRESSED | **Propagation.** L234-241: task records link their live children; discard sets the flags of all live descendants, transitively; a task forked by a discarded task starts discarded; the nested example is given.<br>**Join.** L242-246: the join is a poll point, and a discarded task blocked at its join abandons it and unwinds.<br>**Sentinel identity.** L260-262: no task identity is needed. This holds because ancestor propagation also flags every intermediate task. So when a grandchild's root records `X`, its parent is flagged too and leaves at its own join.<br>**Sketch.** L362-367 restate the `X` invariant across levels.<br>**Tests and changes.** O10 has the nested probe (L389). Change 6 is extended (L437-440). |
| P2 | ADDRESSED | **Both runs.** L208-213 put the condition on both runs and make the fatal-error clause process-wide.<br>**Out-of-memory.** L247-251 now say out-of-memory is process-wide. Two stale references remain (N2). |
| P3 | ADDRESSED | **Assumption.** L216-218 now state it for current lowering.<br>**Invariant.** The lowering invariant, with its test, is in change 5 (L434-436). |
| P4 | ADDRESSED | L238-240 and L262-264 shield tasks forked in cleanup, and O10 adds the probe for `par` inside `defer`. "Skips it" does not say whether the skip covers the shielded task's own subtree (N3). |
| P5 | ADDRESSED | L257-261: cleanup re-panics the sentinel, and a root records `X` for any panic it recovers while its task is flagged, whether sentinel or defect. The controller's named risk is answered under N1. |

### New Problems

**N1 (Minor; required wording). Dropping a discarded task's cleanup defects is correct, but the text does not justify it, and the scoping of D §3 is missing.**

*Decision: drop the defects, and do not report them in any other channel.* A task is flagged only in two cases:
- A sibling to its left recorded a failure.
- An ancestor was discarded. Recursively, that means some task on the ancestor chain has a failed sibling to its left.

In the sequential run, that failure unwinds the enclosing `par` before the flagged task's expression is ever evaluated. So the dropped defect, and every effect of the task, has no counterpart in the sequential run.

*Why nothing recoverable is lost.* A flagged task's outcome is never selected (L362-367). The failure that caused the discard is either selected or dominated by a failure further left, and its causes are reported intact. This is the same "nothing recoverable is lost" argument that D:353-357 makes, applied to the sequential reference run.

*Why reporting the defects separately is wrong.* Whether a discarded task reaches a crashing cleanup at all depends on scheduling. Adding a stderr line or a secondary cause would make the report nondeterministic and break the Determinism row of L373 and O4. That decision belongs to FX002's "secondary report lines" question (L282-284).

*Remaining gap.* D:361-362 lists "dropping the cleanup failure (silent loss)" as a rejected alternative. §10 claims no other spec change is needed (L442), and the argument is not stated anywhere. The text must state it, and the D §3 change must be listed.

Replacements:
- **L257-261.** Replace "sentinel, even if a cleanup raised a defect meanwhile (those causes are dropped with the discarded outcome). A root records `X` for any panic it recovers while its task is flagged, sentinel or defect; no task identity is needed in the sentinel." with:

  > sentinel, even if a cleanup raised a defect meanwhile; those causes are dropped with the discarded outcome. A root records `X` for any panic it recovers while its task is flagged, sentinel or defect; no task identity is needed in the sentinel. Dropping loses nothing the sequential run has. A task is flagged only when a failure was recorded to its left, or to the left of one of its ancestors. In the sequential run that failure unwinds the enclosing `par` before this task's expression starts, so neither its work nor its cleanup defects exist there. The selected failure keeps all its causes (D §3). CF001 does not report dropped causes on any channel, because whether a discarded task reaches a failing cleanup depends on scheduling. FX002 decides whether discarded or cancelled siblings get secondary report lines.

- **Change 6 (L437-440).** Replace "treatment in `waxwingCleanup`, poll masking during cleanup," with:

  > treatment in `waxwingCleanup` (cleanup defects of a discarded task are dropped, see §6; D §3's rejection of "dropping the cleanup failure" is scoped to tasks whose outcome can be selected), poll masking during cleanup,

- **L442.** Replace "No change is needed to row erasure, markers, the `defer`-must-not-fail decision, or (for CF001) the report format;" with:

  > No change is needed to row erasure, markers, the `defer`-must-not-fail decision, or (for CF001) the report format, beyond change 6's scoping of D §3;

**N2 (Minor). Stale fatal-error references after P2.**
- **L373, Determinism, Assumptions column.** "no fatal error in any goroutine (§6)" → "§6 condition (no Go fatal error in the sequential run, or in the process while the construct's goroutines are live)".
- **L390, O11.** "Fatal-error exposure is limited to §6's residual cases" → "Fatal-error exposure beyond the sequential run is limited to process-wide out-of-memory (§6 *Stack and memory*)". The *Residual exposure* bullet no longer names any fatal error.

**N3 (Minor). The shielding scope and the join primitive are underspecified.**
- **L238-240.** Replace "is shielded: propagation skips it and its own join is not a discard point until that cleanup ends (P4)." with:

  > is shielded, together with every task it forks: propagation skips that subtree, so the cleanup's `par` runs to its normal join (P4).

  The old clause "its own join is not a discard point until that cleanup ends" was vacuous, because the cleanup cannot end before that join returns.
- **L245, after "abandons it and unwinds."** Add:

  > Setting a flag therefore wakes a blocked join, and a fork reads its parent's flag and registers under the same lock, so a child forked concurrently with a discard is flagged either way.

  `WaitGroup` cannot be woken early. Both this rule and leftmost selection, which waits for a prefix of the children, need a wakeable join primitive. "Join primitive" is listed under "Can wait" at L415, but O8 cites only `WaitGroup`. Append to O8 (L387): "; the join primitive chosen must give the same publication edge (e.g. a channel send happens before the receive it unblocks)."

**N4 (Minor). Stale "function entry" wording now that joins are polls.**
- **L347-348.** "eager discard stopped at function-entry polls" → "eager discard, propagated to nested tasks and stopped at function-entry and join polls".
- **L389, O10.** "stops at its next function entry outside cleanup" → "stops at its next poll (function entry or join) outside cleanup".

**N5 (Minor). "To completion" is overstated.** L264-265 say "so each cleanup runs exactly once and to completion (O6, C4)". The join does not wait for discarded tasks, so a discarded task may still be in cleanup when the process exits. This is unobservable, because the cleanup is pure. Replace with:

> so each cleanup runs exactly once and, unless the process exits first (unobservable: a discarded task's cleanup is pure), to completion (O6, C4).

Also restore "until program exit" at the end of L253.

**Boundedness.** The design is still bounded:
- Live goroutines never exceed B (L221-225).
- Over budget, children fall back to running inline.
- Discarded tasks free their slot when they exit.
- The only unbounded holds are a discarded task's diverging pure cleanup and its work until the next poll. Both are listed at L252-253.

**§10 and §11 consistency.** Both remain consistent after three rounds:
- Changes 5 and 6 match §6.
- The Task 7 and Task 8 notes cite changes 5 and 6.
- §11's audit items are unaffected by this round.
- The only gap is N1's missing D §3 scoping in change 6 and at L442.

### Verdict

**Accept with fixes.** P1-P5 are addressed. Only Minor wording issues remain (N1-N5), and the exact replacement text for each is given above, ready to apply. Apply N1 before user review: the mechanism is right, but the text currently contradicts D §3 without saying so.
