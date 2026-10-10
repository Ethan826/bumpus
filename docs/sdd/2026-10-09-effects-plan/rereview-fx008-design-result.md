# Re-review: FX008 design note, revision 1

Scope: docs/plans/2026-10-10-abort-tracking-design.md revision 1, checked
against review-fx008-design-result.md. No repository file other than this
one was changed. [ran] means probed with the current compiler; [read]
means reasoning only.

## Verdict: Accept with fixes

One new Critical problem: the late-consumption fixpoint in §3.5 step 1
can loop forever (N1). The other new problems are clarity fixes.

## Status of the earlier findings

| Finding | Status | Reason |
|---|---|---|
| C1 | ADDRESSED | §3.5 step 3 seeds from every N and records sources; §9 adds the cross-function test, the `Handler(nofail …)` parameter and result tests, and the seeding mutant. |
| C2 | ADDRESSED | One list of restricted rows, `Fail` kept for clause rows, judging after late consumption, tests in both orders, and mutants. The new fixpoint brings N1. |
| I1 | PARTLY | Recorded as L4, in §6 and in the diagnostic note. But §6 "Unchanged" still claims too much (N4), and the L4 workaround is wrong for the let-bound handler (N3). |
| I2 | PARTLY | L5 states the `prefix` case accurately. The `run` case is not stated anywhere (N5): a handler parameter whose R is M, installed under a `nofail` own row. |
| I3 | ADDRESSED | §6 has both bullets; D0 added. |
| I4 | ADDRESSED | §5 restated: honesty comes from the solve, the invariant covers the k-th occurrence, the escape argument is given, and late consumption is in step 1. |
| M1 | ADDRESSED | §3.4 and §10 name Use/Stages; `admissible` ignores marks. |
| M2 | ADDRESSED | §3.3 strips marks at the Check-to-IR boundary, including inside `THandler`; §10 cost note. |
| M3 | ADDRESSED | §3.3 normalizes Console and gives Fail a placeholder; §3.2 says how unsolved marks print. |
| M4 | ADDRESSED | §4.6: any `ctl` clause makes its handler M. |
| M5 | ADDRESSED | §3.2: `Handler(nofail Log with Fail(E))` is accepted. |
| M6 | ADDRESSED | D3 rationale corrected. |
| M7 | ADDRESSED | §4.4 wording fixed. |
| M8 | ADDRESSED | §6 says diagnostic texts may move. |
| M9 | ADDRESSED | §9 adds the one-way soundness differential and keeps the oracle test. |
| M10 | ADDRESSED | §4.5 carries the constraint on metas. |

## New problems

**N1 (Critical). The fixpoint does not terminate when a restricted row
shares its tail with its target.** The claim "monotone and bounded by the
labels" is false.

Late consumption adds labels to the target with a fresh left tail. That
bypasses the Leijen side condition. Suppose the restricted row is
`X + t` and its target is `Y + t`, with a key of X missing from Y. Each
round extends t, which also grows the restricted row, so the loop never
ends. The constraint "restricted row ⊆ target" has no finite solution in
this case.

Example, accepted today [ran]. It is a Console-only cleanup inside an
unused lambda:
```
effect Log { fn log(n: Int): Unit; };
fn main(): Unit with Console = {
  let f = fn(u: Unit) => {
    let k = fn(n: Int) => print(n);
    defer k(1);
    with handler Log { log(n) => print(n) } { k(2) }
  };
  ()
};
```
- `k(2)` binds k's tail, which is now the deferred row's tail, to
  `Log + ?h`.
- The target, f's row, is `Console + ?h`.
- Today's single pass adds one spurious `Log` and stops [read]. The
  fixpoint adds one per round, forever.

The same shape without a `defer` also loops. Take a clause that calls a
local lambda the body also calls, inside a lambda whose row stays a meta.
Today that is rejected with `… cannot be made equal: both end in …`
[ran]. Under separate clause rows the body call succeeds, and step 1
then loops [read]. So the success criterion "programs without `defer`
keep their acceptance" fails here: the checker hangs instead of
rejecting.

Fix:
- In step 1, resolve both rows first.
- When the restricted row's tail is the target's tail, or the target's
  tail occurs in it, consume only the labels before the shared suffix,
  and never extend the shared tail.
- If a key is then missing, report the existing side-condition error.
  This rejects the example above; list it in §6 (today's acceptance
  satisfies no finite constraint).
- State a termination measure, or a hard bound that reports an Internal
  error.
- Add both examples as tests.

**N2 (Important). §3.5 omits the passes that already exist.** Today the
order is `settleKeys`, then `settleDeferred` (judge, then late), then
`settleKeys` again (Features/Check.purs:116-118). After that come
comparable and printable, then the entry check.

Write the full order: `settleKeys` (FailNeedsConcrete), step 1,
`settleKeys`, step 2, step 3, closing marks to M, comparable/printable,
step 4, `holes`. Also say that judging moves from before late
consumption (Defer.purs:102-103) to after it. That is required for C2
and can only add rejections.

Deferred keys interact correctly [read]. After the first `settleKeys`
succeeds, every `fail` has a key. Late consumption binds only type and
mark metas, so it creates no new postponed pairs. Keep the second
`settleKeys` as a guard anyway.

**N3 (Minor). The L4 workaround is wrong for a let-bound handler.** For
review I1's second program, a top-level function returning the handler
gives it a constant mark: M, or N/N, which hits L5. The workaround that
works is to write the `handler` expression inline at each use. "A
declaration" works only for the lambda case.

**N4 (Minor). §6 "Unchanged: `defer` of operations under fail-free
lexical handlers" contradicts L4.** Add "except equality merges (L4)".

**N5 (Minor). The `run` case of I2 is unrecorded.** Example:
`fn run(h: Handler(Log with Log + ...e)): Unit with nofail Log + ...e`
installing `h`. R's M Log unifies with the own row's N Log and
mismatches, even though this is sound. Name it in L4, whose fix includes
ρ ⊑ R, or in L5.

## Closing unsolved marks to M (§3.5, §5 step 1)

The claim is valid [read].
- M is the weaker assumption.
- Every demand has already been bound to N.
- Unsolved metas belong to one declaration. Values leave only through
  signature, field and operation types, whose marks are constants.

Conditions to state:
- closing happens after step 3 and before `holes` and the IR stripping;
- `holes` and `foldHoles` never renumber mark metas as type holes.

## L4, L5, and D6/D7 as follow-ups for Task 11

L4 and L5 are accurate apart from N3 and N5. Deferring D6 and D7 leaves
Task 11 workable, because its plan builds handler values inline in `main`
(effects plan Task 11 Step 1). Amend that step on approval:
- **(a) `nofail` along cleanup call chains.** The note's §10 already says
  this.
- **(b) Real and fake handlers share one mark.** Selecting one with
  `if`/`match` makes their marks equal (L4). So every handler a cleanup
  reaches, in both its real and fake form, must be fail-free, or must
  handle its failures inside the clause. A "real" handler that may fail
  cannot serve cleanup; that follows from A1.
- **(c) No callbacks in those clauses.** Clauses on cleanup paths must
  not call callbacks (rigid-tail block).
- **(d) No top-level forwarding handler helpers** (L5).

The dropped-handler diagnostic and the key-count baseline are unaffected.

## Round 3 (revision 2: §3.5 steps 1-7, §6, §7)

Verdict: Accept with fixes. N2-N5 are addressed. N1 is PARTLY addressed:
the fix is sound, but the termination argument depends on provenance.
All findings in this round come from reading the code; nothing was run.

**N1, shared-suffix rule: sound, with two wording fixes.**
- It never extends a tail that the restricted row ends in, so it removes
  the self-loop in the N1 example.
- Fix 1. "A key missing from the target's prefix is an error" is too
  strict. A key present in the target's shared suffix can match there, so
  write "missing from all of the target's labels".
- Fix 2. Define "common suffix" by the first common tail meta in the
  substitution chains (bindings are triangular), not by comparing resolved
  labels. Labels can be equal by value without being shared.
- The rule covers only the direct pair. Take a cycle A→T, B→U, where T
  ends in B's tail and U ends in A's tail. Each round can still add one
  more duplicate of a key around the cycle. Only the per-root measure
  stops that.

**The claim "a copy links to its origin": true for step 2, but the
measure built on it is fragile.**
- True: `consumeVia` links each consumed label `Written origin.span i` to
  its source with `linkTo`, which applies no anonymity filter
  (Consume.purs:52-55). An extension event then links `Extended m` to that
  label (Origin.purs:34). So a label copied in step 2 does reach its
  source.
- Problem 1, it contradicts the spec. Links are provenance. Spec §6 says
  "Provenance never influences typing", and Provenance.purs:50-51 says
  links are not read by unification. Using them to decide what to consume
  makes provenance part of typing.
- Problem 2, "root" is not well defined.
  - Links keep the first one written (Subst.purs:150-155).
  - A `Matched` event links both ways (Origin.purs:32-33), so chains can
    form cycles; `trail` notes "links are not acyclic by construction".
  - A copy made in step 2 can end up inside such a cycle, so "the root
    occurrences that exist when step 2 starts" does not bound anything.
  - `connect` skips anonymous occurrences (Origin.purs:35-37).
  - `Written deferSpan i` ids are reused by every round. That is benign
    only because resolved rows grow by appending.

  Fix: keep copy identity typing-owned. Use a map, local to step 2, from
  each extension meta created in step 2 to the (restricted row, label
  index) it copies. Treat a label as already consumed exactly when it
  maps back to the same pair. The bound is then the restricted labels
  present at the start of step 2.

  A simpler alternative: never extend a tail that ends *any* restricted
  row. Then restricted rows cannot change during step 2, one pass
  suffices, and there is no fixpoint at all. The cost is rare spurious
  side-condition errors; list them in §6.

**N2: ADDRESSED.** The full order is written out as steps 1-7. It moves
judging after late consumption, keeps both `settleKeys` passes, and
closes marks to M before `settle`/`holes`.

**N3, N4, N5: ADDRESSED.**
- N3: L4 now gives the inline-handler workaround for a let-bound handler.
- N4: §6 "Unchanged" carries the L4 exception.
- N5: the `run` case is in §6 and in L5, with directional `with`
  consumption (D7) as the fix.
