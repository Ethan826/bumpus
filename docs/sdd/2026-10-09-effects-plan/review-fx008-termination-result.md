# Focused review: FX008 §3.5 steps 1–3 (revision 4), termination and order

Subject: docs/plans/2026-10-10-abort-tracking-design.md §3.5 steps 1–3,
read with §3.4, §5, §6, §7, spec §2/§6, the two earlier reviews, and
Check.purs, Defer.purs, Consume.purs, UnifyRow.purs, Unify.purs,
Binding.purs, Failure.purs, Scheme.purs, Subst.purs. No repository file
other than this one was changed. [ran] = current compiler (`node
scripts/waxwing.mjs emit`, plus `go run` on the output); [read] =
reasoning about revision 4, which is not implemented. Probes are in
/private/tmp/claude-501/-Users-ethan-Desktop-waxwing/d41c2ee4-6993-4bc5-a1f7-33359afc9a21/scratchpad/termination/.

## Verdict

Revision 4 is not acceptable as written. Two of its properties fail,
the cycle rule hangs on duplicate labels, and the consumption step drops
a clause row's rigid tail. That last one makes the base effect system
unsound, independently of `defer`. A small corrected procedure (below)
gives all four properties.

| Property | Verdict |
|---|---|
| P1 occurrence and multiplicity | ESTABLISHED |
| P2 repeated arrivals constrain | ESTABLISHED (given P3's correction) |
| P3 no early stop | REFUTED as written; ESTABLISHED WITH CORRECTION |
| P4 termination and order | REFUTED as written; ESTABLISHED WITH CORRECTION |
| "a target only grows at its tail" | TRUE |
| rule (c) | Accepts nothing unsound, but loops forever on duplicates and rejects satisfiable cycles |
| topological sweep | Undefined when the graph has allowed cycles; out of date once arguments change the graph (harmless after the correction) |
| (new) clause row with a rigid tail | Unsound acceptance (T1) |

## Model used below

- Restricted row i: own row X_i, target T_i.
- After the body is checked, every binding only refines what a row
  resolves to. A meta is bound once, so a resolved row's label list only
  grows by appending at its tail, and nothing is ever reordered.
- Consumption C(i) unifies `labels(X_i) + f`, with f fresh, against T_i
  (Consume.purs `consumeVia`; UnifyRow `step`).
- Let κ be a key. Under scoped matching, the r-th κ of the left side
  matches the first κ still unmatched on the right. By induction, that
  is the r-th κ of T_i, and it is appended if T_i has fewer than r.

## P1. ESTABLISHED

- The positions are stable. X_i and T_i grow only at their tails, and
  after round 1 (a) every key is fixed (see P3 for the exception). So
  the pairing "r-th κ of X_i with r-th κ of T_i" never changes between
  rounds. Rows that look alike but are distinct do not matter: each pair
  is decided by key and position.
- Multiplicity is right. Suppose X = [Log] is consumed once and a second
  Log arrives later. Re-consuming [Log, Log] pairs the new Log with T's
  second Log, appending one if T lacks it. That is what spec §2 requires:
  the k-th occurrence names the k-th frame.
- Consuming only the new labels would instead pair the late Log with T's
  first Log. That is wrong, so consuming the whole row is needed, not
  just allowed.
- No provenance, link or label identity is read (spec §6). The order of
  source positions breaks ties only; P4 shows it never affects
  acceptance.
- Leaving `Fail` out of deferred rows does not shift the pairing of any
  other key, because pairing is per key.

## P2. ESTABLISHED, given that the round actually runs (P3)

- Each round re-unifies every pair from P1, arguments and marks
  included.
- Pairs already imposed unify terms that are already equal, so they add
  no bindings (idempotent).
- Pairs for new labels are imposed for the first time.
- Nothing is skipped, because no label of the resolved row is filtered,
  except `Fail` in deferred rows, which step 4 rejects anyway.

## "A target only grows at its tail": TRUE

- A row is changed only by binding its tail meta: by extension
  `m := ℓ + m'`, by `unifyTails`, or by a row unification nested in a
  label argument.
- Leijen's rewriting of T into `l' + r3` is only a way of viewing T. It
  binds nothing except T's tail.
- When a consumption's fresh f has entries left over, f is extended with
  them. `unifyTails` may then bind T's tail to f's newest meta. That only
  renames T's tail; no label is added.
- Re-consumption is idempotent whenever no `Fail` key in either row is
  unknown. When one is unknown, the whole pair is put back and set aside
  (`postponed`), which is not idempotent (P3, case 2).

## P3. REFUTED as written

The note claims that binding a type or mark meta inside an argument
creates no obligation, and that nothing else adds a label to a
restricted row. Both claims are false.

**Case 1: a row meta inside a label argument.** Probe argbind.wxw. It is
accepted today [ran]; the analysis of revision 4 is [read].
```
type E = E;
effect Log { fn log(n: Int): Unit; };
effect Cell(a) { fn put(x: a): Unit; };
fn main(): Unit with Console = {
  let z = fn(f) => {
    let h = handler Log { log(n) => f(n) };   // clause row C: tail = f's row ?r
    put(f);                                   // z's row Z = Cell(?a -> ?b with ?r) + ...
    let k = fn(u: Unit) => ();
    defer k(());                              // X := k's row, empty when checked
    let w = fn(u: Unit) => { put(fn(n: Int) => fail(E)); k(()) };  // late: X = Cell(G) + ω
    h
  };
  ()
};
```
- Round 1 consumes X's late `Cell(G)` into Z. It matches `Cell(F)`, so
  G is unified with F. That gives `?r := Fail(E) + …`: C's tail is bound
  by an argument, and no edge of the feed graph is involved.
- If C was visited earlier in the round (it comes first by source
  position), and the exit test counts only extensions along feed edges,
  the loop stops. Then `Fail(E)` never reaches R. h's type is
  `Handler(Log with R)` without `Fail(E)`, although its clause calls
  `f : … with Fail(E) + …`.
- That breaks §5 step 1 ("its own row's labels reach R, including late
  labels"). This is review C2 again, through an argument.
- Today this cannot happen, because the clause row is R itself.

**Case 2: a key that is never settled.** This is a defect in the current
compiler.
- `Fail(a)` with a rigid `a`, written in a parameter row, is accepted
  [ran: failvar.wxw]. Its key never becomes known.
- Every row pair that reaches it is set aside and silently dropped.
  `settleKeys` checks only `fail` expressions (Failure.purs
  `firstUnkeyed`), and settleRows leaves the pairs it cannot decide.
- failvar2.wxw:
  `fn g(h: Int -> Unit with Fail(a)): Unit = h(1); fn main(): Unit with Console = g(fn(n: Int) => fail(E));`
  is accepted today, and at run time panics with
  `panic: no handler for Fail` [ran].
- Spec §2 says a rigid payload is E_TYPE `Fail needs a concrete error
  family`. That is not enforced for rows inside types.
- In the loop, a step (d) consumption that meets such a label is set
  aside whole. All of X_i's labels, not just the `Fail`, then never reach
  T_i, and the exit test sees no change.
- One more effect: an argument binding made in (d) can give an
  instantiated `?a` a head. Step (a) can then decide a pair in round 2 or
  later, so (a) is not limited to round 1.

**Mark metas.** Marks add no labels. They only matter in step 5. No
obligation arises from them in steps 1–3.

**What is correct.** Apart from cases 1 and 2, the only things that add
a label to a restricted row are bindings of its tail meta. These are:
- extension through a feed edge;
- extension through a row unification nested in an argument;
- a pair decided by (a).

**Correction.**
- Exit only after a round in which (a) decided no pair *and no
  restricted row's resolved label count changed, by any binding*.
  Counting is enough, because rows only append.
- A pair still set aside when the loop exits is E_TYPE `Fail needs a
  concrete error family`, at the restricted row.
- Separately, make `settleKeys` reject any pair still set aside. That
  closes the case 2 defect, which exists without FX008.

With these, if a round changes nothing, every X_j ⊑ T_j that was
re-established in that round still holds at its end:
- X_j did not change;
- T_j only grew at its tail;
- argument equalities are preserved by later substitution;
- keys are fixed.

## P4. REFUTED as written

**4a. Rule (c) misses an excess that comes from duplicates, so the loop
never ends.** Probe dup.wxw. It is accepted today [ran]; the analysis of
revision 4 is [read].
```
effect Log { fn log(n: Int): Unit; };
fn main(): Unit with Console = {
  let f = fn(u: Unit) => {
    log(0);
    let k = fn(n: Int) => print(n);
    defer k(1);
    with handler Log { log(n) => print(n) } { k(2) }
  };
  ()
};
```
- Once the body is checked, X = [Console, Log, Log] + τ and f's row is
  F = [Log, Console] + τ: a self-loop.
- Every label of X has its key somewhere in F, so (c) calls the loop
  harmless.
- Step (d) then appends a Log to τ in every round, forever.
- The rule must count occurrences per key, not check whether a key is
  present.

**4b. Rule (c) rejects cycles that are satisfiable.** Probe
cycle2open.wxw. It is accepted today [ran]; revision 4 rejects it
[read].
```
effect Log { fn log(n: Int): Unit; };
effect Tick { fn tick(): Unit; };
fn main(): Unit with Console = {
  let g = fn(u: Unit) => {
    let k = fn(n: Int) => print(n);
    k(0);
    let h = handler Log { log(n) => { defer k(n); tick() } };
    with h { log(1) }
  };
  ()
};
```
- There are two feed edges: X → C (the defer's target is C itself) and
  C → X (R = g's row, whose tail is k's tail, which is X's tail).
- C's `Tick` is missing from R, so (c) reports an error.
- But one extension, Tick into the shared tail, satisfies both rows. X
  then has Tick, and C already has it.
- When g is called under a Tick handler (cycle2.wxw), the tails close
  while the body is checked, and today's run prints `0 7 1` [ran].

**Exact rule.** Weights are per key:
w_i(κ) = count_κ(X_i) − count_κ(T_i), over resolved labels.
- Growth of the classes must satisfy u_T(i) ≥ u_X(i) + w_i. Here a
  class is an unbound tail meta, and u is the number of labels later
  appended to it.
- That system has a finite solution if and only if no cycle has a
  positive sum Σ w_i(κ) for any key.
- On a cycle, each class is the target tail of one member and the own
  tail of the next. Growth adds equally to one count of T and one count
  of X, so a cycle's sum never changes.
- Edges are never removed: two rows that end in the same unbound meta
  keep ending in the same meta.
- So a positive cycle, once present, proves there is no solution,
  whenever and in whatever order it is found.
- A self-loop is the special case A ≤ B for each key. That is exact,
  and it is the case of N1 and of dup.wxw.

**4c. A bound for the open term, which the note left unsettled.**
- Let N0 be the number of unbound row-meta classes when the loop starts.
  No step creates a class:
  - an extension continues its class under a fresh meta;
  - a consumption's fresh f is bound to the target's remainder in the
    same step.
- A row unification nested in an argument that grows a row with an
  unbound tail does one of three things:
  - it merges that tail's class with another;
  - it binds the tail to a closed row or a rigid variable;
  - it meets the same tail, which is Leijen's side condition and an
    error.
- Each of the first two removes a class. So there are at most N0 changes
  to the graph or argument-level growths in total, giving at most N0 + 1
  epochs.
- Within an epoch the graph is fixed, and only extensions along edges
  happen. Each extension is exactly the Bellman–Ford relaxation
  u_T := max(u_T, u_X + w).
- With no positive cycle, a sweep of all rows reaches its fixpoint in at
  most V + 1 rounds, where V ≤ 2n classes.
- Total: rounds ≤ (N0 + 1)(2n + 1) + 1, plus the number of pairs (a)
  decides. In the usual case (no edges) there are 2 rounds, so the
  8,000-defer linearity test is unaffected.

**4d. Order.**
- Topological order is undefined when cycles exist, and revision 4
  allows harmless ones. Use the SCC condensation. The order is fixed
  when (b) builds the graph; edges created during the round take effect
  in the next one.
- With the corrections, order matters only for efficiency. Acceptance
  holds if and only if a finite solution exists:
  - Each consumption is the most general unifier step of an equation
    that every solution must satisfy (f is fresh). Leijen's scoped
    unification is complete.
  - So every intermediate state is more general than any solution: no
    unification failure, no positive cycle, and termination by 4c.
  - The state at exit is a solution.
  - That condition does not mention order.
- Diagnostic texts may still depend on order; fix them canonically
  (source order).
- Ties between siblings are ESTABLISHED as not mattering, including
  same-key labels with different arguments.
  - Feeders i and k share a target tail m. In any order, the equations
    are: for each r, the argument of X_i's (c_i + r)-th κ equals the
    argument of m's r-th κ, and likewise for X_k with c_k. Here c is the
    target's own count of κ before m.
  - In either order, `State(Int)` against `State(Bool)` reaching the
    same m's first State is a mismatch [read, both orders traced]. Only
    the headline differs.
  - The order of different keys inside m is not observable.

**4e. Is (c) unsound anywhere?** No accepting outcome is unsound: a
"harmless" verdict either needs no extension or loops (4a). Its defects
are a hang (4a) and imprecision (4b).

## T1 (new, Critical). Consuming "with a fresh tail" drops a clause row's rigid tail

§3.4 and §3.5 (d) consume only the labels of a clause row into R. A
clause that calls a callback typed with the ambient row has a clause
row with no labels and the rigid ambient as its tail. Nothing then
forces R to contain that tail. Probe rigid.wxw: rejected today
(`Expected Handler(Log), found Handler(Log)`) [ran]; revision 4 accepts
it [read].
```
type E = E;
effect Log { fn log(n: Int): Unit; };
fn mk(g: Int -> Unit): Handler(Log with pure) = handler Log { log(n) => g(n) };
fn main(): Unit with Console = {
  let h = handle mk(fn(n: Int) => fail(E)) { fail(error: E) => mk(fn(n: Int) => ()) };
  with h { log(1) }
};
```
- Under revision 4 the clause row is `[] + ambient`, and there is
  nothing to consume into `pure`.
- The rigid tail blocks only the mark (§3.4), and m simply stays M.
- At run time `log(1)` reaches `fail(E)` with no `handle` around it.
- So this is a hole in the base effect system, like C2.

Fix: after the loop, a clause row whose resolved tail is a rigid ϱ needs
R to end in ϱ.
- Bind R's unbound tail meta to ϱ; if R is closed or ends in another
  variable, give the missing-capability error.
- Repeat while that binding gives another clause row a rigid tail. Each
  pass binds a distinct meta.
- This must not happen inside the loop. Binding R's tail early would
  turn away a later feeder's extension (the result would depend on
  order).
- This binding adds no labels, so it cannot reopen the loop. A defer
  whose tail it makes rigid is rejected by step 4, which is correct in
  every solution.

## Corrected procedure (replaces §3.5 steps 1–3)

1–3. **Settle keys and consume late labels, as one loop.** Each round:
- (a) Run `settleKeys`.
- (b) Resolve every restricted row X_i and its target T_i.
  - Build the feed graph: i → j when T_i's and X_j's tails resolve to
    the same unbound meta.
  - Fix the round's order: a topological order of the graph's strongly
    connected components, with source position inside and between them.
- (c) For each key κ, let w_i(κ) = count_κ(X_i) − count_κ(T_i), leaving
  out `Fail` keys for deferred rows.
  - If some cycle, self-loops included, has Σ w_i(κ) > 0, report the
    side-condition error at that cycle's earliest row with w_i(κ) > 0.
    Such a cycle has no finite solution, and its sum never changes.
  - Cycles whose sum is ≤ 0 for every key are allowed.
- (d) In that order, consume each row's resolved labels with a fresh
  tail into its target. Clause rows keep `Fail`; deferred rows leave it
  out.
- Exit after a round in which (a) decided no pair and no restricted
  row's resolved label count changed, whatever binding caused the
  change. Argument-level row bindings count.
- On exit:
  - A pair still set aside is E_TYPE `Fail needs a concrete error
    family`.
  - Then run the clause-tail pass (T1).

Bound: at most (N0 + 1)(2n + 1) + 1 rounds, plus the pairs (a) decides
(4c). Acceptance holds exactly when the containments and equalities
have a finite solution, so it does not depend on order (4d).

Changes to the note's text:
- Delete the P3 claim that argument bindings create no obligation.
- Delete "one topological sweep moves every label as far as it must go".
- §6 must list dup.wxw as newly rejected. It is accepted today and has
  no finite solution, like N1.
- cycle2open.wxw stays accepted.

## Fallback ("never extend a tail that ends any restricted row")

These programs are accepted today [ran, with the run output shown]. The
fallback rejects each of them [read]; revision 4 [read] and the
corrected procedure accept each.

1. f1.wxw: a defer inside a clause gets a late `Tick`, whose target is
   C's tail. Output `1 2`.
   ```
   effect Log { fn log(n: Int): Unit; };
   effect Tick { fn tick(): Unit; };
   fn main(): Unit with Console = {
     let k = fn(n: Int) => print(n);
     with handler Tick { tick() => print(0) } {
       let h = handler Log { log(n) => { defer k(n); () } };
       k(1);
       with h { log(2) }
     }
   };
   ```
2. f2.wxw: a clause inside a defer gets a late `Tick`, whose target R is
   X's tail. Output `1 2`.
   ```
   effect Log { fn log(n: Int): Unit; };
   effect Tick { fn tick(): Unit; };
   fn main(): Unit with Console = {
     let k = fn(n: Int) => print(n);
     with handler Tick { tick() => print(0) } {
       { defer with handler Log { log(n) => k(n) } { log(1) }; () };
       k(2)
     }
   };
   ```
3. f3.wxw: there is no `defer`. This is review C2's late `Fail(E)`
   inside another handler's clause, where R_inner is the outer clause
   row. Output `9`. Rejecting it breaks the success criterion that
   programs without `defer` keep their acceptance.
   ```
   type E = E;
   effect Log { fn log(n: Int): Unit; };
   effect Tick { fn tick(): Unit; };
   fn main(): Unit with Console = handle {
     with handler Tick { tick() => {
         let mk = fn(g) => handler Log { log(n) => g(n) };
         let h = mk(fn(n: Int) => fail(E));
         with h { log(1) }
       } } { tick() }
   } { fail(error: E) => print(9) };
   ```
4. cycle2open.wxw (4b) is accepted today [ran]. The fallback and
   revision 4 both reject it; the corrected procedure accepts it.

Recommendation: do not choose the fallback. Example 3 alone disqualifies
it.

## Minor

- argbind-internal.wxw, the argbind program installing `h` inside `z`,
  is E_INTERNAL `Effect row consumption failed` today [ran]. A
  `RowOccurs` during consumption at `with` is reported as internal. It
  is a pre-existing diagnostic defect and should be logged.

## Verified by running vs by reading

- [ran] These are accepted today:
  - n1.wxw, dup.wxw, cycle2.wxw (`0 7 1`), cycle2open.wxw;
  - f1 (`1 2`), f2 (`1 2`), f3 (`9`);
  - argbind.wxw, failvar.wxw;
  - failvar2.wxw, which panics `no handler for Fail` at run time.
- [ran] rigid.wxw is rejected today, and so is rigid-ok.wxw
  (side-condition text). argbind-internal.wxw is E_INTERNAL today.
- [read] Everything about revision 4 and the corrected procedure:
  - the hang in 4a, the rejection in 4b, the missed obligation in case 1;
  - T1's acceptance and its run-time failure;
  - the bound, the invariance of cycle sums, and order independence;
  - the sibling traces;
  - the fallback's rejections.
