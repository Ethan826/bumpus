# Review: FX008 design note, revision 7 (the R/C split)

Subject: docs/plans/2026-10-10-abort-tracking-design.md rev 7, read with the
rev 6 review, spec §2-§3, and Handler.purs, Consume.purs, UnifyRow.purs,
Unify.purs, Apply.purs, Check.purs. No repository file other than this one
was changed. [ran] = current compiler (`node scripts/waxwing.mjs run|emit`);
[read] = reasoning about rev 7, which is not implemented. New probes:
/private/tmp/claude-501/-Users-ethan-Desktop-waxwing/d41c2ee4-6993-4bc5-a1f7-33359afc9a21/scratchpad/rev7/.

## Verdict: Accept with fixes

- No unsound acceptance found: no cleanup ending in a typed abort, and no
  base-effect hole.
- The split restores meta2 and hole2c. It does **not** restore today's
  inference in general (I1).
- "R ≡ ρ ignoring marks" is underspecified at row extension (I2).
- Two safe programs are newly rejected and missing from §6:
  - a C = R alias in local annotations (I3);
  - a merge through R's shared tail (I4).
- I1 needs a user decision. The other findings are fixes to the text.

## Critical

None.

## Important

**I1. Clause rows feed R only at construction and in the loop. Today the
clause row *is* R. Programs without `defer` are rejected (refutes §3.4 "R
behaves exactly as today", §0 and §6 "Unchanged").** late1.wxw is accepted
today and prints `0` [ran]:
```
effect Log { fn log(n: Int): Unit; };
effect Get(a) { fn get(): a; };
fn main(): Unit with Console = {
  let k = fn(u: Unit) => ();
  let h = handler Log { log(n) => k(()) };
  with handler Get(Handler(Log with Console)) { get() => handler Log { log(n) => print(n) } } { k(()) };
  let g = fn(u: Unit) => with h { with get() { log(1) } };
  print(0)
};
```
- Today:
  - the clause's `k(())` makes k's row tail R's tail;
  - the later `k(())` binds it to `Get(H), Console`;
  - so `g`'s `get()` is known to be a handler.
- Control late1ctl.wxw: the same program with the clause `log(n) => ()`
  gives E_TYPE `Expected a handler` [ran]. The link runs through the
  clause row.
- Rev 7 [read]:
  - c's tail is shared with k's row, but c was consumed into R (fresh
    tail) when it was still empty;
  - R gains `Get(H)` only in the §3.5 loop;
  - `with get()` decides its head eagerly (Handler.purs `headOf`), so
    E_TYPE `Expected a handler`.
- late2.wxw [ran: accepted]: the binding comes *after* g's `with h`, and
  `g2 = fn(u) => { g(()); with get() {…} }` uses it.
  - Re-consuming c into R at each `with` would fix late1 but not late2.
- Apply.purs `open` also binds an unknown callee eagerly to a pure arrow.
  Changes of this kind surface as rejections. I found no silent change in
  Go output, since the loop runs before holes default [read, not
  exhaustive]. Cases resolved later are unaffected: late3.wxw, a
  comparison resolved in the loop, stays accepted [ran today; read rev 7].
- Fix (user decision):
  - (a) eager one-way propagation. When a clause row's tail meta is
    bound, consume the new labels into R immediately, as a substitution
    hook. This restores today's inference.
  - (b) Or accept the change: pin late1 and late2 as rejected in §6 and
    amend §0 and success criterion 3.
  - Making c ≡ R does not work. c would then absorb ρ through R's tail, so
    C = all of ρ, and every frame becomes the join of its context (rev 6
    I3's around2 problem, everywhere).

**I2. "R ≡ ρ ignores marks" does not say what mark a label gets when this
unification *extends* a row. The unifier inserts label objects
(UnifyRow `absent`/`finish` → `extendRow entry.label`), so a literal
implementation shares marks by identity.** With identity:
- merge1.wxw is rejected [read]. It is accepted today, printing `1 9`
  [ran]:
  ```
  let h = handler Tick { tick() => () };
  let g1 = fn(u: Unit) => { with h { () }; defer tick(); () };
  let g2 = fn(u: Unit) => { with h { () }; tick() };
  with handler Tick { tick() => print(1) } { g1(()) };
  with handler Tick { tick() => fail(E) } { g2(()) }
  ```
  - g1's defer adds `Tick^t` to the class {R, ρ_g1};
  - g2's `R ≡ ρ_g2` copies `Tick^t` into ρ_g2 by identity;
  - so M → f_fail → t → d → N.
  This is the I1 let-bound-handler class, which §6 says is no longer
  rejected.
- A signature-typed form is also rejected [read]:
  `fn f(h: Handler(Log with Tick)): Unit with nofail Tick = { let g =
  fn(u: Unit) => { with h { log(1) }; defer tick(); () }; g(()) }`.
  ρ_g receives the written `Tick^M` from R, and the defer fails with
  M ⊑ d ⊑ N. The program is safe.
- Fix:
  - Specify that a label added to either side by R ≡ ρ, or by R ≡ R when
    two handler types unify (also unstated), gets a fresh mark meta with
    no edge. This is sound: every needed edge on ρ comes from C's
    consumption, the frame constraint and call-site consumption.
  - Equivalently, R's marks are dead. Add a mutant: "R ≡ ρ extension
    shares marks ⇒ merge1 rejected".

**I3. Written types have C = R as one row. For a local annotation, R is
flexible and R ≡ ρ shares its tail, so C *is* unified with a context
(contradicts §3.4 "C is never unified with a context"). The I4 (annotb)
fix is incomplete.** annotc.wxw is accepted today and prints `1 5 9`
[ran]:
```
let h = handler Log { log(n) => print(n) };
let inst = fn(x: Handler(Log)) => { with x { log(1) }; defer tick(); () };
with handler Tick { tick() => print(5) } { inst(h) };
with handler Tick { tick() => fail(E) } { with h { tick() } }
```
- Rev 7 [read]:
  - `R_x ≡ ρ_inst` shares the tail;
  - the defer extends it with `Tick^t`, t ⊑ d ⊑ N, so C_x = R_x contains
    `Tick^t`;
  - `inst(h)` gives C_h ≡ C_x with marks included, so C_h gains `Tick^t`;
  - `with h` under the failing Tick gives f_F ⊑ t. So M → N.
- annotd.wxw (defer before the `with`) is rejected the same way under
  identity extension (I2). It is accepted with fresh marks.
- Fix: give a written handler type its own C row:
  - signatures: a structural copy, with the same written marks and the
    same closed or rigid tail;
  - local annotations: the written labels with fresh mark metas and a
    fresh tail meta.
  Add a mutant: "C aliased to R in local annotations ⇒ annotc rejected".

**I4. R ≡ ρ1 ≡ ρ2 makes contexts share a tail, which rev 6 had
separated. A safe program is newly rejected, and §6/L4 do not list it.**
merge2.wxw is accepted today and prints `1 9` [ran]:
```
let h = handler Tick { tick() => () };
let g1 = fn(u: Unit) => with h { () };
let g2 = fn(u: Unit) => with h { () };
let a = fn(u: Unit) => { g1(()); defer tick(); () };
let b = fn(u: Unit) => { g2(()); tick() };
with handler Tick { tick() => print(1) } { a(()) };
with handler Tick { tick() => fail(E) } { b(()) }
```
- Rev 7 [read], under either extension rule:
  - g1 and g2 share one tail class through R;
  - a's defer puts `Tick^t` (t ⊑ d ⊑ N) in it;
  - b's `g2(())` extends ρ_b with t′ ⊑ t;
  - the failing handler gives M ⊑ f_F ⊑ t′. So M → N.
- Rev 6 accepted it [read]. merge2ctl.wxw, with separate handler literals
  (accepted today [ran]), is accepted by rev 7 [read]. So the merge is
  R-specific.
- This is sound (only an equality is added), and it is the price of
  restoring inference.
- Fix:
  - §6 "Newly rejected" and L4: tails shared through one handler value's
    R are a second source of the residual merge;
  - pin merge2 in §9;
  - qualify §6 "No longer rejected: I1's let-bound handler": it holds
    when the installation contexts are concrete. I1's own program is
    accepted [read].

## Minor

- **M1.** §3.4 says "a rigid clause tail binds … R's through ordinary
  unification as today". That is false under consumption with a fresh
  tail. Only the §3.5 tail pass binds R's tail. Consequence: rev 7
  *gains* programs rejected today.
  - rig1.wxw and rig2.wxw are rejected today [ran]: `f performs Tick,
    which its signature does not allow`. Their clause calls an `...e`
    callback, and a lambda performs `tick()` around `g(())`.
  - Rev 7 accepts both, soundly, as `R = [Tick | e]` [read].
  - Fix: §0 and §6 should say "keep or gain" and list rig1, or bind R's
    tail eagerly (same hook as I1 (a)). Delete the §3.4 clause.
- **M2.** §5 step 1 still says "every label the clauses perform is in R,
  by the restricted-row consumption", and its outer occurrence ⊑ f. This
  must be C. Add "C ≡ C, marks included" to "Handler values reach
  installations only by type equality". The §5 last paragraph should say
  that rev 7 also changes `with`.
- **M3. Stale text.**
  - §3 heading: "revision 6".
  - §8 `handler` rule: "Handler(m L with R) … exact R" should say exact C.
  - §4.2 lacks the I2 extension mark (fresh t ⊑ s), which the rev 6
    review asked to be put there.
  - §3.4 should state that R ≡ R (two handler types) ignores marks.
- **M4.** "C's unsolved tail closes to empty" also closes a context's
  tail while I3's alias exists. This is moot after the I3 fix.

## Answers

1. **Soundness: ESTABLISHED [read].** The base system is sound through C:
   - c is consumed into C, late labels are re-consumed by the loop, C is
     consumed into ρ, and the tail pass requires ρ to end in ϱ;
   - R only adds equalities.

   Mark soundness:
   - every edge that ρ needs comes from C's directional consumption, the
     frame constraints, and call-site consumption, so R's marks are dead;
   - fresh or shared marks on R extension, the C = R alias, and shared
     tails all add constraints only;
   - `Fail` in C matches the first `Fail(E)` of ρ, which is the `handle`
     outside the `with` (the body prepends only L);
   - scoped duplicates pair by first occurrence in both R and C;
   - handler values through let, `if`, parameters, results, fields and
     type arguments carry C by type equality with marks;
   - the target-extension mark t ⊑ s is sound and order-independent;
   - fresh mark metas in local annotations are sound;
   - the §5 least-solution witness is correct.
2. **Restores inference: REFUTED** (late1, late2). meta2, hole2c, extb,
   annotb and the I1 programs are restored [ran today; read rev 7]. "Marks
   ignored" NEEDS FIX (I2). It leaves no needed mark unconstrained.
   Shared-tail merges through R are real (I4, merge2) but do not hit
   extb, annotb or the I1 let-bound program. l4b stays L4.
3. **§6 precision: NEEDS FIX.**
   - Newly rejected, unlisted: late1 and late2 (no `defer`), annotc,
     merge2, and merge1 under the identity reading.
   - Newly accepted, unlisted: rig1 and rig2.
   - Listed items: correct.
4. **Restricted-row machinery: ESTABLISHED, with I3.**
   - R is a target only. Its tail is ρ's tail, so feed edges from c→R
     entries reach rows ending in ρ's tail. The rev 5 argument covers
     arbitrary feed graphs.
   - The C = R alias creates self-loops C_x→ρ of weight 0. That is
     harmless, and gone after the I3 fix.
   - The tail pass on R binds ρ's tail, which matches today's
     errors.
5. **Ready for written-spec approval: not yet.** It needs the I1 decision,
   the I2 and I3 rule text, the I4 and M1 compatibility entries, and M2
   and M3.

## Ran vs read

- [ran], current compiler:
  - accepted: late1 `0`, late2 `0`, late3, merge1 `1 9`, merge2 `1 9`,
    merge2ctl `1 9`, annotc `1 5 9`, annotd `1 5 9`;
  - rejected: late1ctl `Expected a handler`; rig1 and rig2 `f performs
    Tick, which its signature does not allow`;
  - all rev6/ probes re-run with the same results as the rev 6 review
    (meta2 accepted, meta3 ambiguous, extb `12 0 9`, annotb `1 2`, l4b
    `0`, around5 `101`, con E_INTERNAL, con2 accepted);
  - hole2c's emitted Go is byte-identical to rev6/hole2c.go.
- [read]: every rev 7 outcome above, the soundness argument, the loop and
  tail-pass check, and the eager-decision search (Handler `headOf`, Apply
  `open`).
