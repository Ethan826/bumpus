# Review: FX008 design note, revision 6

Subject: docs/plans/2026-10-10-abort-tracking-design.md rev 6, read with
AGENTS.md, spec §2/§3/§6, CF001 §5 R0 and O-2, BACKLOG FX007/FX008, the three
earlier FX008 reviews, and Check.purs, Handler.purs, Consume.purs,
Defer.purs, Use.purs, HandlerType.purs, Specialize/Lower.purs,
Format/Go/Context.purs. No repository file other than this one was changed.
[ran] = current compiler (`node scripts/waxwing.mjs run|emit`); [read] =
reasoning about rev 6, which is not implemented. Probes:
/private/tmp/claude-501/-Users-ethan-Desktop-waxwing/d41c2ee4-6993-4bc5-a1f7-33359afc9a21/scratchpad/rev6/.

## Verdict: Accept with fixes

I found no unsound acceptance. That covers cleanup ending in a typed abort,
and also the base effect system after `with` stops unifying R with ρ. The
path check is correct. The rev 5 loop, extended to installed R entries,
still terminates, apart from I2's order caveat.

The fixes are about claims and examples:
- D7 changes type inference for some programs without `defer` (I1). This
  contradicts the binding constraint "Go output unchanged" and the §0/§6
  compatibility claims, so the user must decide.
- The mark that extension gives a new label is unspecified (I2).
- The D6 flagship example is ill-typed even without marks (I3).
- §6 omits several safe programs that become rejected (I4).

No earlier finding regresses (C1, C2, I1-I4, M1-M10, N1-N5, P1-P4, T1).

## Critical

None.

## Important

**I1. Consuming R at `with`, instead of unifying it, loses type information.
Programs without `defer` can be rejected, and Go output can change.**
- Today `R ≡ ρ` at every installation, so two installations of one handler
  value make their contexts' rows equal. Inference uses that link.
- meta2.wxw is accepted today [ran]:
  ```
  type Opt(a) = No | Some(a);
  effect Log { fn log(n: Int): Unit; };
  effect Cell(a) { fn put(x: a): Bool; };
  fn main(): Unit with Console = {
    let h = handler Log { log(n) => () };
    let g1 = fn(u: Unit) => with h { let v = No; if put(v) then print(v == v) else () };
    let g2 = fn(u: Unit) => with h { if put(Some(true)) then () else () };
    ()
  };
  ```
- Today `v : Opt(Bool)` is solved only through `R ≡ ρ_g1 ≡ ρ_g2`. Under rev 6
  the two lambda rows are unrelated, so `v`'s type stays `Opt(_)`. The
  result is E_TYPE `Ambiguous type Opt(_) in comparison`. That is today's
  exact error for meta3.wxw, the same program with a separate handler in
  `g2` [ran].
- Go output: an unsolved meta defaults to Int (hole4.wxw emits an `int32`
  field [ran]). hole2c.wxw (`put(No)` / `put(Some(true))` under one shared
  `h`, nothing applied) emits one `Opt(Bool)` layout today [ran]. Rev 6
  would also emit `Opt(Int)` and a second `Cell` layout [read].
- The same mechanism can leave a deferred `Fail` key unsolved, giving
  E_TYPE `Fail needs a concrete error family`.
- This refutes:
  - §0 "Programs without `defer` keep their acceptance and meaning";
  - A3 / the constraint "Go output unchanged";
  - §4.3 and §3.4 "accepts strictly more" / "at least what equality
    accepted";
  - §6 "Unchanged".
- Fix: needs a user decision. D7 cannot keep R ≡ ρ, because shared
  occurrences would share marks. Either accept the change and amend §0,
  A3, §4.3 and §6, with meta2 as a pinned rejection and the Go-default
  consequence stated, or drop the `with` half of D7 (and with it I1's
  second program and the two-row install).

**I2. The mark of a label added to a target by extension is unspecified.
Sharing by identity rejects safe programs and makes acceptance depend on
order.**
- §3.4 specifies copies only when a *stage's* tail is bound. When the
  target's tail meta is extended with a stage label (a lambda row
  receiving R's labels at `with`, a `defer`, or a call), the new target
  label either shares the stage label's mark or gets a fresh one.
- extb.wxw is accepted today and prints `12 0 9` [ran]:
  ```
  type E = E; effect Log { fn log(n: Int): Unit; };
  fn main(): Unit with Console = handle {
    let fwd = handler Log { log(n) => log(n + 10) };
    let g = fn(u: Unit) => { with fwd { log(2) }; defer log(0); () };
    with handler Log { log(n) => print(n) } { g(()) };
    with handler Log { log(n) => fail(E) } { with fwd { log(1) } }
  } { fail(error: E) => print(9) };
  ```
- Under rev 6 with identity [read]:
  - `with fwd` extends g's row with R's `Log` (mark r);
  - the failing install gives `M ⊑ f_fail ⊑ r`;
  - the defer gives `r ⊑ d ⊑ N`;
  - so M→N, and the program is rejected. That is the I1 class rev 6
    claims to remove.
- With a fresh `t ⊑ r` there is no path, and the program is accepted.
- In the loop, two feeders extending one tail produce `X ⊑ Y` or `Y ⊑ X`
  depending on which runs first. That breaks property 4 (acceptance
  independent of order).
- Fix:
  - Extension creates the target label with a fresh mark t and the edge
    `t ⊑ s`. This mirrors copies, and both directions are sound.
  - Say this in §3.4 and §4.2.
  - Add a mutant ("extension shares marks ⇒ extb rejected").

**I3. The D6 example (§3.2) and its §9 acceptance test do not type-check in
the base effect system.**
- around.wxw is the note's `prefix`/`around` with the marks removed. It is
  rejected today with `around performs Log, which its signature does not
  allow` [ran]. There are two independent causes:
  - `prefix()` without `with pure` puts prefix's ambient into R, and the
    call binds that ambient to the caller's row. Even
    `with prefix() { log(1) }` alone fails (around2.wxw [ran]). Under rev 6
    R picks up copies of the whole context, so the frame's mark depends on
    every mark in that context (f is constrained by all of them).
  - `body: Unit -> Unit with Log + ...e`, called under the extra `Log`
    frame, fails: the rigid `e` cannot absorb the second Log (around3.wxw,
    around6.wxw [ran]).
- The corrected form runs today and prints `101` (around5.wxw [ran]):
  `prefix(): Handler(Log with Log) with pure` and
  `body: Unit -> Unit with Log + Log + ...e`.
- With marks it must be
  `body: Unit -> Unit with nofail(k) Log + nofail(k) Log + ...e`. A
  distinct `j` on the first Log gives `k ⊑ f ⊑ j`, the forbidden path k→j
  [read].
- A related pitfall: `Handler(nofail Log)` without `with pure` has R equal
  to the callee's rigid ambient. Inside the callee, every installation of
  such a parameter is therefore M. So review C1's `run` example and the §9
  test "a `Handler(nofail Log)` parameter given a failing handler" reject
  in the callee's own body, not at the call.
- Fix:
  - Correct §3.2 and the §9 tests.
  - Write `with pure` on handler-returning helpers and on `Handler(nofail …)`
    parameters.
  - Consider a diagnostic hint for an installation that is M only because
    R ends in a rigid tail.

**I4. §6 omits safe programs that become rejected and do not depend on a
failing handler that cleanup reaches.** §6 says "Each case depends on a
handler that may fail". Two counterexamples, both accepted today:
- **L4 example**, which the note asks the plan to find. l4b.wxw prints `0`
  today [ran]:
  ```
  type E = E; effect Log { fn log(n: Int): Unit; };
  fn main(): Unit with Console = handle {
    let k = fn(u: Unit) => ();
    let g = fn(u: Unit) => { k(()); defer log(0); () };
    with handler Log { log(n) => print(n) } { g(()) };
    with handler Log { log(n) => fail(E) } { k(()) }
  } { fail(error: E) => print(9) };
  ```
  - `k(())` makes k's row share g's tail, and the defer's Log then lands
    in that shared tail.
  - k's second use gives `M ⊑ f_fail ⊑ x ⊑ d ⊑ N` under either extension
    rule [read].
  - So a no-op lambda poisons the defer. Pin it as the L4 example.
- **Local annotations.** annotb.wxw prints `1 2` today [ran]:
  ```
  effect Log { fn log(n: Int): Unit; };
  fn main(): Unit with Console = {
    let h = handler Log { log(n) => print(n) };
    let inst = fn(x: Handler(Log)) => with x { log(1) };
    inst(h);
    with h { defer log(2); () }
  };
  ```
  - §3.4 says "Written labels are M". So the lambda annotation's M
    equals h's m, and the defer is rejected [read].
  - A lambda parameter needs an annotation for `with` (ExpectedHandler),
    and `nofail(k)` is signature-only. So there is no local way to stay
    mark-polymorphic.
- Fix:
  - Unmarked labels in *local* (lambda) annotations get fresh mark metas.
    This is sound (they are locals) and matches the flexible row in local
    annotations: amb3.wxw shows a lambda's `Handler(Log)` R absorbing
    `Tick` inside a `with Tick` function [ran].
  - Otherwise list annotb in §6 and L1.
  - List l4b under L4 and in §6.

## Minor

- **M1, §5 witness.** Closing leftover metas to M (step 6) is not a
  solution: x ⊑ N with x closed to M violates it. §5 needs the witness:
  for each valuation of the mark variables, the least solution (x = M iff
  an M-valued atom reaches x). Say that closing affects only erasure.
- **M2, placement.**
  - The own-abort constraint, the frame constraints ("labels of R resolved
    at settling", "R's resolved tail rigid") and the frame pairing must be
    generated after the loop and the tail pass, from resolved rows by
    first occurrence. Say so in §3.5 step 5.
  - "R's unsolved tail closes to empty" is not placed in §3.5. It must
    come after the tail pass.
  - The tail pass's repeat condition says "another clause row". It must
    also cover installed R entries, which the generalisation requires.
    Deferred rows are left to step 4.
- **M3, §3.6.** One "first incoming edge" per node cannot rebuild the path
  from a particular atom when several atoms reach the node. Keep a
  predecessor per (node, atom). That is still O(edges × atoms).
- **M4, property 1 wording.** "Keys are fixed after the first round" drops
  the termination review's exception: a pair that (a) decides in a later
  round. Restate it as "a key, once decided, never changes; labels with
  undecided keys are set aside whole". The argument is unaffected.
- **M5, consistency.**
  - §11 D3 says "all three opening positions"; §3.4 now has two.
  - §0 says "keep their acceptance"; §6 says "keep or gain".
  - §3.5 says "steps 2, 4, 5 and 6 new": step 4 already exists and moves,
    and steps 1-3 are one loop.
  - The §10 Task 11 bullet list ends with a stray ";".
- **M6, Console.**
  - Copies give Console labels fresh metas. Keep copies of Console at N.
  - `fn f(h: Handler(Console with pure)): Unit with Console = with h {
    print(1) }` is accepted today (con2.wxw [ran]). Its frame label is not
    "normalized at resolution". Reject Console as a handled label in
    types, or normalize the frame.
  - Pre-existing defect: `handler Console { … }` gives E_INTERNAL `Invalid
    handler effect` (con.wxw [ran]). The note's "runtime is its only
    handler" relies on this. Needs a BACKLOG row and a user diagnostic.
- **M7, syntax gaps.** Specify:
  - `nofail(k) Console` (ignored?) and `nofail(k) Fail(E)` (E_TYPE, as
    `nofail`);
  - whether k shares the namespace of type variables (`x: k` together with
    `nofail(k)`);
  - whether lambda annotations in a body may name the signature's k.
- **M8, equalities.** §3.3 keeps mark metas in the substitution, while
  §3.5 counts equalities as two edges. Both are fine, but say which, and
  that edges are read on resolved marks.
- **M9, extra copies.** Copies onto the throwaway fresh tail in loop step
  (d), and in the `pure ⊆ ρ` coercion, are never read. Skip them so that
  each round does not grow the mark graph.

## Priority answers

1. **Soundness.** No counterexample. I tried these probes [read]:
   - handler values under several rows, through let, lambda, `if`,
     parameters, results, fields, operation arguments and results, and row
     variables shared with the own row (`run`'s `R ≡ ?e`, bound to copies);
   - late labels into R, and installed entries re-consumed;
   - rigid R tails, inside and outside the callee;
   - `Fail` in R reaching the handle outside the `with`;
   - nested installs of one value, and duplicates;
   - `defer` inside clauses and `with`/`handle` inside cleanup. Cleanup
     safety comes from R's labels entering D, not from f, which is
     correct.
   - mark variables, opening of parameters and results, and escaping
     lambdas.

   Frame marks never leak by identity, since f sits only in a body row's
   prefix and nothing unifies env.current with anything else. Both
   extension rules in I2 are sound. Go lowering drops R and rows
   (Lower.purs:49, IR `TFun FunTypeId`) [read], so the Go output changes
   only through I1.
2. **Path check: correct.**
   - Each constraint is a Horn implication "x = M ⇒ y = M". For a fixed
     valuation it is satisfiable iff no M-valued atom reaches an N-valued
     one.
   - Quantified over the k (∀k ∃metas, the witnesses being internal),
     the forbidden pairs are exactly M→N, M→k, k→N and k→k′ with k ≠ k′.
   - No other constraint form exists: the conditional rules are decided on
     resolved rows before step 5.
3. **Rev 5 procedure with installed R: holds**, with I2 (symmetric
   extension marks needed for order independence) and M2 (the tail pass
   repeat must include installed R).
   - R is a target of clause entries and a source of installation entries.
   - Feed edges, per-key cycle weights, the epoch bound and the exit test
     carry over, because consumption uses a fresh tail and so never binds
     X's tail.
   - Copies create labels, not row classes.
   - The tail pass binds only unbound metas, to rigid variables, which is
     necessary in every solution, and adds no labels.
4. **§6.**
   - Wrong, by I1 and I4.
   - "No longer rejected" (I1, I2, N5) is plausible [read].
   - n1/dup as newly rejected: consistent.
   - "Programs without `defer` keep acceptance" holds *for rows* (today's
     solution C = R = ρ satisfies rev 6's containments, so the complete
     loop accepts), but not for inference (I1).
5. **Readiness.** After I1 (user decision), I2-I4 and M2, ready for
   written-spec approval and planning.

## Verified by running vs reading

- [ran] On the current compiler:
  - §1 program: exit 1, `fail(E): E`.
  - meta2: accepted. meta3: `Ambiguous type Opt(_) in comparison`.
  - hole4: unsolved meta defaults to `int32`. hole2c: a single
    `Opt(Bool)` layout.
  - extb `12 0 9`, l4b `0`, annotb `1 2`, amb/amb3 accepted, amb2
    `Unhandled Tick in main`.
  - around, around2, around3, around6: rejected. around5: `101`.
  - con: E_INTERNAL. con2: accepted.
- [read] Everything about rev 6's behaviour:
  - meta2's rejection and hole2c's changed output;
  - extb's, l4b's and annotb's rejections;
  - the marked `around` signature;
  - the soundness search, the path-check argument and the loop re-check.
