# Review: FX008 revision 8, the one-way hook (§3.4)

Subject: the one-way hook in docs/plans/2026-10-10-abort-tracking-design.md
rev 8, read with review-fx008-rev7-result.md and Handler.purs, Consume.purs,
Unify.purs, UnifyRow.purs, Subst.purs, Binding.purs, Apply.purs,
Failure.purs, Check.purs. No repository file other than this one was
changed. [ran] = current compiler (`node scripts/waxwing.mjs run|emit`).
[read] = reasoning about rev 8, which is not implemented. New probes are in
/private/tmp/claude-501/-Users-ethan-Desktop-waxwing/d41c2ee4-6993-4bc5-a1f7-33359afc9a21/scratchpad/rev8/.

## Verdict: Accept with fixes

- The hook restores late1, late2, rig1 and rig2, and every single-handler
  probe.
- The §6 claim about the lost reverse link is **refuted**. Four programs
  without `defer` are accepted today and change under rev 8:
  - three are rejected;
  - one changes its emitted Go.
- As written, the hook can **diverge**, on programs that today reject with
  the side-condition error.
- Both have small fixes (F1, F2). Soundness is unaffected.

## Critical

None. No unsound acceptance. The hook adds only equalities and labels to
R, whose marks are dead. Base effects still go through C, the loop and
the tail pass.

## Important

**I1. Two handlers whose clause rows share a tail lose today's link
R1 ≡ R2 (refutes §3.4 "can only gain acceptance, or leave a type meta
unsolved that nothing observes", and §6 "Unchanged").**

two1.wxw is accepted today and prints `0` [ran]:
```
type Opt(a) = No | Some(a);
effect Log { fn log(n: Int): Unit; };
effect Cell(a) { fn put(x: a): Bool; };
fn main(): Unit with Console = {
  let k = fn(u: Unit) => ();
  let h1 = handler Log { log(n) => k(()) };
  let h2 = handler Log { log(n) => k(()) };
  let g1 = fn(u: Unit) => with h1 { let v = No; if put(v) then print(v == v) else () };
  let g2 = fn(u: Unit) => with h2 { if put(Some(true)) then () else () };
  print(0)
};
```
- Today:
  - c1 = R1, c2 = R2, and both share k's tail T, so R1 ≡ R2;
  - g1's `Cell(Opt(?b))` meets g2's `Cell(Opt(Bool))`.
- Rev 8 [read]:
  - c1 and c2 share T, but R1 and R2 are fed one-way and are otherwise
    unrelated;
  - nothing ever binds T (k is called only in the clauses), so the hook
    never fires;
  - result: `Ambiguous type Opt(_) in comparison`.
- two1ctl.wxw (h2's clause does not call k) reproduces exactly that
  substitution today, and is rejected with that error [ran].

Same class, each accepted today [ran], with a faithful control that
gives the rev 8 outcome [ran ctl]:

| Program | What it does | Rev 8 outcome |
|---|---|---|
| two3.wxw | the late1 shape through h1/h2 | E_TYPE `Expected a handler` (`with get()`, Handler `headOf`) |
| two1f.wxw | `let v = get(); fail(v)` under h2, `Get(E)` around h1 | E_TYPE `Fail needs a concrete error family` |
| two2.wxw | hole2c through h1/h2 | still prints `0`, but emitted Go changes from an `Opt(Bool)` layout to `int32` plus a second `Cell` effect type (diffed, [ran]) |

two2 breaks §0's criterion "emitted Go stays byte-identical". §3.4 instead
allows Go text changes, so the two texts contradict each other. Rev 6
treated hole2c as a regression.

Why only this class [read]:
- Every row other than R that comes to share c's tail does so through
  unification. Anything such a row adds to that tail is a binding, so the
  hook routes it into R, where it meets ρ's labels.
- Pairing is preserved: c's r-th κ pairs with R's r-th κ, as today, where
  c is R.
- one1.wxw, one3.wxw and one1rev8.wxw are single-handler versions. They
  are accepted today [ran], and rev 8 accepts them through the hook
  [read].
- The rows that are linked to a clause tail only one-way are the other
  handlers' R. So the only lost equalities are R_i ≡ R_j for handlers
  whose clause tails meet.

No run-time behaviour change was found:
- holes default to the representative;
- the other differences are rejections.

Fix F1: when the hook finds that clause rows of two different handlers
resolve to the same tail meta (at a binding *or* a meta-to-meta merge),
unify R_i ≡ R_j, ignoring marks, as for R ≡ R. This restores today's
equalities exactly [read].
- Cost: the contexts of both handlers share a tail, as in merge2. Add
  this as a third source to L4 and pin two1 and two3 in §9.
- Alternative: pin two1, two3, two1f and two2 in §6, and amend success
  criteria 3 and 4.

**I2. The hook does not terminate on positive cycles.** cyc2.wxw is
rejected today with E_EFFECT `... and Tick + ... cannot be made equal:
both end in ...` [ran]:
```
let k = fn(u: Unit) => ();
let h = handler Tick { tick() => k(()) };
let g = fn(u: Unit) => with h { k(()) };
```
Rev 8 [read]:
1. R ≡ ρ_g shares tails.
2. The body's `k(())` against `Tick + ρ_g` binds T := [Tick | ρ_g's tail].
3. The hook consumes c = [Tick | t] into R = [ | t]. Tick is absent from
   R, so the hook extends t, which is c's tail.
4. That binding fires the hook again, and so on forever.

This is the n1/dup self-loop (a prepended `with` label), now on a c→R
edge.
- Consuming only the "newly arrived" labels, as the text literally says,
  also loops here.
- It would also mispair duplicates, so the whole row must be consumed
  (§3.5 property 1).
- cyc3.wxw is a two-handler cycle (h1's body calls k2, h2's body calls
  k1). It is rejected today with `... and Log + Tick + ... cannot be made
  equal` [ran], and rev 8 diverges through c2→R2~c1→R1~c2 [read].

Fix F2:
- The hook consumes the whole clause row, with a fresh tail (as loop step
  (d)).
- Before it does, it applies §3.5 (c)'s per-key cycle test to the c→R
  edges whose targets' tails resolve to clause tails. A positive sum
  reports today's side-condition error.
- Simplest form: in one cascade, a clause row that fires again with a
  larger label count is a positive cycle.
- With sums ≤ 0, each consumption adds no label to the shared class, so
  the cascade stops.
- Positive cycles here coincide with today's shared-tail rejections, so no
  acceptance changes [read; not proven].

## Minor

- **M1. Stale contradiction.** §3.4 line 334 says "A rigid clause tail
  binds both C's and R's tails, through that pass only (review rev7 M1)".
  The hook bullet binds R's tail at once.
  - Replace the line with: the tail pass binds C, and binds R only for
    rigid tails that arise during settling. It is a no-op when R already
    ends in the same ϱ.
  - No conflict between the two bindings arises. Two different rigid
    tails are an error in both systems, and today too.
- **M2. "R's tail is bound to that variable" is imprecise.** After
  R ≡ ρ, R's tail is already bound to ρ's rest. The intended meaning is
  "R's resolved unbound tail meta := ϱ". That makes ρ end in ϱ at once,
  as today.
  - A *closed* clause tail leaves R open. This is a gain over today: in
    late1, R is closed today.
  - Rev 8 also gains when a clause's callback has a rigid row and R
    already holds ρ's labels: today that is a RowExtra error, and it is
    sound [read]. Say both in §6.
- **M3. Mark-free.** State that the hook's consumption ignores marks, and
  that labels it adds to R get fresh mark metas with no edge. Otherwise R
  labels that share ρ's tail by identity (L4) gain edges into c's marks,
  contradicting "R's marks are dead". This is harmless for soundness.
- **M4. "Watched" must follow the resolved tail.** `unifyTails` binds the
  larger meta to the smaller. So c's tail meta can join another class
  without being bound, and later labels then bind the other meta. Watch
  c's resolved tail, re-targeted after each binding. This is also where
  F1's merge test goes.
- **M5. Order.** The hook replays today's timing, since today c is R and
  labels reach R when they reach c. That holds provided it runs before
  every eager decision:
  - `withHandler` `headOf`;
  - Apply `open`/`functionLike`;
  - Hint.

  Apply's `bindArrow` uses an open row, so it is not an irreversible
  decision. Final acceptance does not depend on when the hook runs: each
  step is the forced, first-occurrence consumption [read].

## Implementability (Q4) [read]

Do not put the hook inside Unify, Binding or Subst as a callback:
- unification is a pure `Subst → Either Failure Subst`, nested inside
  type, label-argument and postponed retries;
- a hook failure there would be reported against an unrelated pair's
  operands;
- `consumeVia`'s origin and link recording lives in State and Consume, so
  provenance notes for R's labels would be lost;
- UnifyRow already imports Binding, so the consumption would have to be
  threaded back in.

Recommended:
- Subst gains `watched` and `dirty` sets of tail metas.
- `bindTail` and `extendRow` (Binding.purs), on a watched meta, add it to
  `dirty` and watch the new fresh or target tail. This is data only, with
  no checker state.
- Postponed reverts drop `dirty` naturally.
- A checker-level `sync` (Handler or Consume; State holds the
  clause-row→R table) drains `dirty`:
  - for each affected clause row: F2's cycle test, then the F1 merge test,
    then `consumeVia` of the whole row into R with a fresh tail, mark-free,
    with the clause's span as origin, then the rigid-tail binding.
- Call `sync` after each `infer` node and before the eager decisions in
  M5. The §3.5 loop covers bindings made in `settleRows`.
- Cost is proportional to dirty rows only, so linearity (T003) is kept.

## Answers

1. Restores today's behaviour for late1, late2, rig1, rig2 and every
   rev6/rev7 probe: **ESTABLISHED [read]**.
   - Every rev6/rev7 probe re-run today gives the results recorded in the
     rev 7 review [ran].
   - late1/late2: `k(())` binds T, so the hook gives R `Get(H)`, so ρ_g has
     it. R stays open (M2).
   - rig1/rig2: `cb(())` makes c end in `e` at construction, as today.
2. "Only gains or unobserved metas": **REFUTED** (I1: two1, two3, two1f,
   two2), for two handlers whose clauses share a callee.
   - One-handler forms are restored (one1, one3, one1rev8).
   - No run-time behaviour change found.
   - F1 restores today's behaviour.
3. Well-defined and terminating: **REFUTED** (I2: cyc2, cyc3 diverge).
   - Fixed by F2 plus whole-row consumption.
   - Order-independent and consistent with the loop and the tail pass,
     after M1 and M2 [read].
   - Soundness unaffected, after M3 [read].
4. Implementable as data in Subst plus a checker-level sync, without
   making unification depend on checker state.

## Ran vs read

- [ran]:
  - accepted, printing `0`: two1, two2, two3, two1f, one1, one3,
    one1rev8, late1, late2;
  - rejected: two1ctl (Ambiguous `Opt(_)`), two3ctl (Expected a handler),
    two1fctl (Fail needs a concrete error family), cyc2 and cyc3 (shared
    tail E_EFFECT), rig1 and rig2 (`f performs Tick`);
  - two2 vs two2ctl Go diff, which differs;
  - all rev6/ and rev7/ probes unchanged from the rev 7 review.
- [read]: all rev 8 outcomes, faithfulness of the ctl emulations (in
  rev 8, T is never bound in two1, two2, two3 or two1f), the divergence
  traces, the fixes, soundness and implementation.
