# Re-review: CF001 operational addendum fix round, 2026-10-10

Scope: the fix diff (rereview-cf001-ops.diff) against review-cf001-ops-result.md,
checked against the current doc, effects design §4 (`with` rule, lines 264-271, 138-140),
src/Features/Check/Handler.purs (withHandler) and src/Format/Go/Cleanup.purs (usesDefects).
Line numbers below refer to the current docs/plans/2026-10-09-concurrency-foundations-design.md.

### Finding Verdicts

| Finding | Verdict | Evidence |
|---|---|---|
| C1 | ADDRESSED (FX002 hole closed), but mis-justified for CF001 (see N1) | 448: send/await become operations of a built-in non-Fail label (`Send`) in the façade's clause row; 530 O-3; 455; 594-602 §9 note; 609 §10 item 1 |
| I1 | ADDRESSED | 416-419: built-in policy only, no Waxwing code receives a cause list, opaque outcome deferred as a D9 decision; 528 O-1 |
| I2 | ADDRESSED | 419-423: supervisor-cancelled tasks record `X`, their cleanup causes go only to the event line, only the trigger escalates; 429 row; 528 |
| I3 | ADDRESSED | 389-398: restart only after cleanup completes; past the deadline abandon, never restart, escalate; a cleanup defect counts once; initializer failure counts; window and clock later; 531 O-4 |
| I4 | ADDRESSED, precise | 431: the current column is gated on `usesDefects` (matches Cleanup.purs:29-38: only `crash` and `defer`); guard panics and Go fatal errors are Go's, default exit 2, GOTRACEBACK varies. The proposed column is labelled "proposed contract". 532 O-5 and 666-669 say "not a Waxwing guarantee". Not overclaimed. One wording nit: N3 |
| I5 | ADDRESSED | 506: an unsupervised defect cancels `main`'s scope; `main` reports after its cleanup, exit 1; the report still originates in `main`; 534 O-7 |
| I6 | ADDRESSED | 429 row, 532 O-5, 665-667 ADR note. "Today every non-first cause" is true per Cleanup.purs:13 |
| M1 | ADDRESSED | 372 |
| M2 | ADDRESSED | 385 "at least the holders" |
| M3 | ADDRESSED | 448 (exactly once, no timeout removal, no intermediate replies; lattice reads trusted only, §4.7), 474 (one deterministic sender, no deadlines) |
| M4 | ADDRESSED | 471-473: full-mailbox send cycles, C5 waits, O-3 self-call cross-reference |
| M5 | ADDRESSED | 482-487 (CF001 fields vs "contract only"), 533 O-6, consistent with §9 (601) |
| M6 | ADDRESSED | 505: the adapter recovers at the callback boundary and re-raises; never unwinds through C frames |
| M7 | ADDRESSED | 437-438 (8A.2), 497-498 (8A.5) |
| M8 | ADDRESSED | 427 |
| M9 | ADDRESSED | 534 O-7: every blocking wait is a cancellation point (extends C1) |

### New Problems

**N1 (Important). Lines 198-205, 293, 543, 594-600, 609 and 760: B3b rests on a false premise about the type system. As a capture rule it is redundant, incomplete and over-restrictive.**

- **The premise is false.** B3b and the §9 note claim that `par let a = fail(E), b = with logH { log("x") };` "has Fail-only rows (B2)" because "by B2 an installed handler's clause effects are invisible in the child's row".
- **What the rules actually say.**
  - The effects design `with` rule (effects-design 270-271): "`with h { body }`, `h : Handler(L with R)` ... R is unified with ρ (opened if closed, as consumption)".
  - The implementation agrees: Handler.purs `withHandler` calls `consumeVia ... row` on the handler's clause row before checking the body.
  - So `b`'s own row contains Console, and R0 already rejects the example: `a par child may only fail, but it performs Console`.
  - B2 is about clauses of handlers installed *outside* the child. Their rows were consumed at the parent's `with`, and under R0 a child never performs their non-Fail labels; C1 at §7 already says so.
- **The original C1 premise was likewise only true for FX002 primitives outside every row.** The `Send` label fixes that (448, 530). Given the `with` rule, R0 alone then keeps façades out of `par` children.
- **There is no CF001 conflict.** The "required rejection test" passes through R0 whether or not B3b exists, so it cannot test B3b.
- **Named risks.**
  - *Decidability.* Inertness is decidable at check time, because clause rows are in `Handler(L with R)` and row erasure happens only in lowering. But B3b as worded ("transitively through handler-typed captures") does not reach:
    - handlers inside captured data (`T(Handler(Log with e))`);
    - handlers inside captured closures. A closure's type shows the clause effects only as its call row, which R0 sees anyway.
  - *Over-restriction.* B3b rejects programs that do nothing observable:
    - capturing a handler parameter with an ambient row (bare `Handler(Log)` in a signature: a rigid tail, so "not closed");
    - capturing any handler with a non-Fail clause row that the child only passes along or returns and never installs.
  - *Local pure state is fine under both rules.*
    - FX001 `constant` State handlers have pure clause rows.
    - A child's own `with` of a fresh handler is not a capture.
    - FX003 local state is excluded by B3 (not Shareable).
  - *Interaction with R0.* B3b is a second check at capture sites, in addition to R0's row check after constraints settle. It is coherent but duplicative, and a different R0 strictness (FX007) would not carry over to it.
  - *`Send`.* The label is sufficient because of the `with` consumption rule and R0, not because of B3b. It must be a built-in label like Console: discharged only by the runtime at task roots, and never declared local.
- **Fix:** demote B3b to a derived observation and restore the earlier wording elsewhere. Exact text:
  - **Replace lines 198-205** with:
    > **B3b. No hidden clause effects (added 2026-10-10, §8A.3).** Shareable captures plus R0 already make a child's observable effects row-visible: `with h { … }` consumes `h`'s clause row R into the installing row (effects design §4 `with` rule), so `par let a = fail(E), b = with logH { log("x") };` with printing `logH` is rejected by R0 (`… but it performs Console`), and a handler parameter with an ambient row is rejected when installed (rigid tail). Parent-installed clauses never run in a child (R0, §7 C1). The only route around this is a runtime primitive outside every row, so FX002 façades perform a built-in non-Fail label (`Send`, discharged only by the runtime, O-3). Required test: the example above, rejected by R0.
  - **Line 293:** "(R0) with Shareable captures (B3); B3b explains why no clause effect hides from R0."
  - **Line 543:** "only Shareable values (B3), with conditional sequential equivalence and"
  - **Line 448 fragment** "façade Shareable but not inert: … so B3b keeps it out of `par` children" becomes "façade Shareable; send/await are operations of a built-in non-Fail label (`Send`) in its clause row, so installing it in a `par` child puts `Send` in the child's row and R0 rejects it (B3b)".
  - **Line 455:** "is rejected in CF001 (R0 via `Send`, B3b): discarding `b` after its send is observable."
  - **Line 530 O-3 tail:** "communication is a built-in row-visible label (`Send`), so R0 keeps façades out of `par` children (B3b)."
  - **Lines 594-600** become:
    > **Addendum impact (2026-10-10).** No conflict for FX001/CF001 programs: `with` consumes a handler's clause row into the installing row, so R0 sees every effect a child can cause (B3b). FX002 façades keep this only if communication is a row-visible built-in label (O-3); B3b adds a test, not an exclusion. The subset, R0, B1-B5, selection, the discard contract and O1-O11 are unchanged.
    The sentence "Additive: … covers stderr." stays.
  - **Line 609:** drop ", with B3b inert captures"; append "(B3b: façade communication must be a row label)".
  - **Line 760:** "C1 (B3b observation, O-3 `Send` label; no CF001 conflict, since `with` consumes clause rows)".

**N2 (Minor). Line 668: the ADR note says the report is "present only with `defer` or `crash`".**
- This is true for FX001, but CF001 adds `par` (B4: "a program with `par` emits the defect runtime").
- Replacement: "present only with `defer` or `crash` (from CF001 also `par`)".

**N3 (Minor). Line 431: "(`crash` aborts)" reads as Waxwing's `crash`.**
- Replacement: "(`GOTRACEBACK=crash` aborts, SIGABRT on Unix)".

**§9/§10 impact on FX001 Task 12.** It remains wording only:
- three ADR 010 sentences: open cause kinds, the meaning-based `cleanup failed: ` prefix, and exit status as Go's behaviour;
- no Task 10 interpreter or report code change.

N1's rewrite removes the claimed conflict and changes nothing in FX001.

### Verdict

**Accept with fixes.**
- Apply N1. It is text-only: the fix round introduced a false claim of a CF001 conflict and a redundant capture rule.
- N2 and N3 are verbatim minors.
- All 16 findings are addressed.
