# Focused re-check: FX008 revision 10, corrections T, F1′ and S

Subject: docs/plans/2026-10-10-abort-tracking-design.md rev 10, §3.4
"One-way hook" (F1′, F2, correction T, scheduling, correction S) and §3.5
as it interacts. D0–D7 were not reopened. Read with
review-fx008-rev9-f1f2-result.md, review-fx008-termination-result.md and
review-fx008-rev8-hook-result.md, and with UnifyRow.purs, Binding.purs,
Consume.purs, Handler.purs, Unify.purs, Subst.purs, Scheme.purs, Apply.purs,
Call.purs, Pipe.purs, Hint.purs, Failure.purs and Check.purs. No repository
file other than this one was changed.

Tags: [ran] = run today (`node scripts/waxwing.mjs run`). [read] =
reasoning about rev 10, which is not implemented. New probes are in
/private/tmp/claude-501/-Users-ethan-Desktop-waxwing/d41c2ee4-6993-4bc5-a1f7-33359afc9a21/scratchpad/rev10/.

## Verdict: no substantive issue

| Property | Verdict |
|---|---|
| 1. Termination | ESTABLISHED WITH CORRECTION (wording only: N1) |
| 2. Inference compatibility | ESTABLISHED for rejections caused by a failure. The solvedness half is ESTABLISHED by the supplement in 2b. Marks: ESTABLISHED. One unlisted gain (N3), which is sound |
| 3. Scheduling | ESTABLISHED (precision note N2) |

No unsound acceptance was found. No today-accepted program was found that
rev 10 rejects. All the corrections below are about wording or precision.
Each one closes off a reading of the text under which an implementation
would go wrong.

## 1. Termination

**1a. Is signature test T sound? Yes** [read]. A clause row needs a new
consumption only when the equation `labels(c) + φ_[t] ≡ R` it last imposed
no longer implies the current one. Unification facts persist, so that
happens only in these cases:
- **labels(c) grew.** Rows grow only at the tail, and the prefix order is
  fixed (UnifyRow `absent`/`finish` extend the tail; resolution only walks
  tail bindings). So equal per-key counts mean the same label sequence.
  Same-key labels cannot be reordered.
- **The class's φ changed.** That means a merge with another clause class,
  or a change of kind (rigid or closed).

Changes T does not need to catch:
- **Argument changes.** R's labels hold the same argument terms, either by
  extension or by a pairing already unified. A type binding is seen
  through them directly.
- **Key changes.** A key cannot change after the label is in a row. Labels
  enter rows only by `absent`/`finish`, which require a decided key and
  otherwise postpone. Postponed pairs are retried only in `settleKeys`
  (Failure.purs, called at Check.purs:116). A key, once decided, is fixed.
  So the counts are always well defined.
- **Argument-level row bindings** (argbind). These go through
  `bindTail`/`extendRow` on the watched tail itself.

**A merge with another class of the same kind is caught.** At least one
side's identity changes. Re-consuming the absorbed side with the surviving
φ alone forces the φ merge, by cancellation:
`P + φ_a ≡ R ≡ P + φ_s ⇒ φ_a ≡ φ_s`. The explicit F1′ unification is
therefore redundant but harmless.

**A merge with a class that holds no clause row needs no work.** Examples
are R's tail, ρ's tail, a fresh tail, or φ itself. It changes no φ and no
count. It can create a new feed edge. But every up-to-date hook edge has
w = count(c) − count(R) ≤ 0, because `labels(c) + φ ≡ R` gives
count(R) ≥ count(c). Cycle sums are invariant. So no positive hook-only
cycle can appear without some row's signature changing.

**N1 (wording, needed for termination).** The text must say how a class
is identified and how φ is keyed. The reading "class = representative
meta, with a fresh φ for each new representative" diverges on cyc1, which
is accepted today and prints `0` [ran]. Trace [read] (metas count down, so
`unifyTails` binds the older meta):
1. The clause gives c = k = [Log | x1].
2. The hook does `r := Log + r1` and `φ := r1`, so R = [Log | r1].
3. g's `k(())` does `x1 := y1`. That is a rename. A fresh φ′ gives
   `r1 := φ′`.
4. `with h` unifies R with ρ_g. That gives `y1 := φ′`, so c's tail is R's
   tail (the class now holds its own φ).
5. A fresh φ″ gives `φ′ := φ″`, which re-dirties c with a new
   representative. Then φ‴, and so on, forever.

Both of these readings terminate:
- **(i)** Class identity ignores merges with classes that hold no clause
  row (this is the text's "a rename is not a change"). Step 4 is then not
  a change.
- **(ii)** φ is attached to the class and carried across representative
  changes. Each rename then costs one no-op consumption, because the
  equation already holds and so nothing is bound.

Either way, an extension t := L + t′ must start a new class with a fresh
φ_t′. Keeping φ_t would make the next consumption fail with
`… both end in …` (`absent`'s shared-tail check).

Proposed text: "A class is a union-find class of unbound row metas. It
keeps its identity, and its φ, when it merges with a class that holds no
clause row. An extension starts a new class with a fresh φ." The text's
justification ("which every fresh-tail consumption causes") is rev 9
language. Under F1′ the renames come from φ meeting R's or ρ's tail.

**1b. Cycles** [read]:
- **Indirect and duplicate cycles.** F2 uses the per-key sums on c→R
  edges, with c's own tail (see N2). Only hook consumptions bind anything
  during `sync`. So unbounded growth needs a cycle made only of hook
  edges, and F2 sees those. Duplicates are counted per key (dup.wxw).
- **Cycles exposed by F1′ φ merges.** These were already argued in rev 9
  1b. The extra φ_t′ that each extension creates is absorbed in its first
  consumption: it is bound, or merged with R's remainder tail. So the
  number of unbound classes never increases.
- Zero-weight cycles, such as the two-row cycle c1→R1~t2 and c2→R2~t1,
  produce only renames. These are no-ops under N1.

**1c. The bound** (N0 + n_c + 1)(2n_c + 1)·n_c per `sync` is correct as an
upper bound, given N1 [read]:
- Epochs: φ merges, rigid tails and closed tails each remove an unbound
  class. Extensions keep the number of classes the same.
- Within an epoch, the counts follow Bellman–Ford over at most 2n_c
  nodes, with no positive cycle.
- Under reading (ii), add at most one no-op consumption per binding that
  `sync` makes.

**1d. Interleaving with §3.5** [read]:
- `sync` never runs inside the loop. Correction S replaces it there.
- `sync` runs at most once per node and once per eager-decision site, and
  each run is finite.
- Under S, each (d) consumption absorbs the φ_t′ it introduces. So the
  loop's claim that "no step creates a new row-meta class" holds net, and
  its bound (N0 + 1)(2n + 1) + 1 is unchanged.

## 2. Inference compatibility

**2a. The mapping argument covers every rejection caused by a failure**
[read]. Write E′ for the clause and body equations with each c_i, and E
for today's, where every c_i is R. Then:
- Today's mgu θ composed with [c_i ↦ R] solves E′.
- Induction over the rev 10 run, where μ is the current mgu and θ′ = θ″∘μ:
  every new hook equation `labels(c) + φ_[t] ≡ R` is solved by
  φ_[t] ↦ θ″(t), because θ′(c) = θ(R).
- The assignment is consistent:
  - a merge t1 ≡ t2 gives equal images;
  - t := L + t′ gives φ_t ≡ L + φ_t′;
  - a rigid tail gives ϱ;
  - a closed tail gives ∅, which matches the text's "closes φ_t" (N4);
  - φ ≡ t (cyc1) is trivially consistent.

What this covers:
- **The same handler, and different handlers.** This is the same
  construction. A state such as sh1's (P_a ≠ P_b on one class) cannot
  arise when today accepts: it would need P_aθ″ + X = P_bθ″ + X.
- **Consumption with marks ignored, and extension.** Marks are not part
  of θ.
- **The cycle test, in the hook and in the loop's (c).** A finite solution
  exists, so no cycle has a positive sum.
- **Installed C.** C ↦ the union of the clause labels, which is a subset
  of θ(ρ) = θ(R).
- **The tail pass, and rigid or closed tails.** θ(ρ) = θ(R) ends where
  θ(c) ends.
- **Settling-time merges (S).** These are the same equations, imposed
  later.

**2b. Supplement: solvedness** [read]. The mapping shows only that rev 10's
mgu is *at least as general* as today's. That is the wrong direction for
outcomes that depend on a type being solved:
- an eager decision (`Expected a handler`, arity);
- `Ambiguous …`;
- `Fail needs a concrete error family`;
- Go defaulting.

§3.4 lines 414–419 still rest this half on probes. The argument that
closes it:
- Today's only extra equation is t_i ≡ φ_[t_i]. It makes the remainder Q
  (ρ's labels beyond P_i) visible to rows S that share t_i.
- Every pairing of a Q label with another label happens in a unification
  that involves S. In rev 10 the other label then *arrives at a watched
  tail of class t_i*, whether S is the stage or the target. Leftovers
  extend S's tail, and a closed or rigid S closes or rigidifies the class.
- The hook then pairs the label at the same index of the t-part: R's
  (count_κ(P_i) + j)-th κ, which is Q's j-th κ, as today.
- Pairings with R itself (R ≡ ρ) are literally today's.
- So the type metas get the same solution, and only rows that share t_i
  lose Q's labels.

Probe pair1.wxw is accepted today and prints `0` [ran]. pair1ctl.wxw
breaks the link and gives `Ambiguous type Opt(_) in comparison` [ran].
Rev 10 accepts pair1 by this argument, because m's `Cell(Opt Bool)`
arrives at x and meets g's `Cell(Opt ?b)` in R [read]. The text should
replace the probe-only claim with this argument, and fix the stale "F1"
on lines 414–416 to F1′.

**2c. The converse: gains**:
- sh1 stays rejected [ran today; read rev 10: `labels(c_a) + φ ≡ R ≡ φ`
  hits `absent`'s shared-tail check, giving today's message].
- ov1 and ov1f are accepted [ran today; read rev 10: R1 = [|φ],
  R2 = [Tick|φ], and φ := [Console]].
- **N3: an unlisted gain.** gain1.wxw:
  ```
  let k = fn(u: Unit) => ();
  let h = handler Log { log(n) => k(()) };
  let g = fn(u: Unit) => { if put(true) then () else (); with h { log(1) } };
  k(());
  ```
  - Today it is rejected with `Unhandled Cell(Bool) in main` [ran]. R ≡ ρ_g
    puts `Cell(Bool)` into k's row.
  - gain1ctl.wxw, with the link broken, is accepted [ran].
  - Rev 10 accepts gain1 [read]: φ takes `Cell(Bool)`, x does not, and
    k's row closes to [Console].
  - It is sound. The base effects go through C, the loop and the tail
    pass. k performs nothing, and R is inference only.
  - §6 says only "can only gain acceptance". Pin gain1 in §6 and §9 as
    newly accepted.

No other kind of gain exists. By 2a and 2b, rev 10 differs from today only
in the labels of rows that share t_i.

**2d. R's marks are dead** [read]. Every operation on R ignores marks:
- R ≡ ρ, R ≡ R, the hook, and (d) into R (rev 10 now says so);
- the F1′ φ unifications.

Labels added to R by extension get fresh marks with no edge. C is only
ever extended with fresh, edged copies, so no C mark is ever an R object.
Identity sharing still occurs through *tails*, never through R's marks:
- ρ_i ~ ρ_j through a shared φ (L4, third source);
- c ~ ρ when the program makes them share a tail (cyc1: g and the clause
  both call k), which is L4's primary source.

An R≡ρ′ label that lands in a clause tail shared in this way has a fresh,
unconstrained mark. If the clause later pairs with it, edges are added to
that object, so C ⊑ c ⊑ s still chains. This is sound.

## 3. Scheduling

**3a. No missed obligations** [read]:
- **Row bindings.** The only places that insert into `rows` are
  Binding.purs:81 (`bindTail`) and :121 (`extendRow`), which I grepped.
- **Postponed pairs.** A pair reverts to `operands.start`, which carries
  `dirty`. `sync` never runs inside a pair.
- **The hook's own consumption is never postponed.** c and R hold only
  decided keys.
- **Pairs retried at settling.** `settleRows` runs only from `settleKeys`,
  so retried pairs reach R only through S (set1).
- **`sync`'s own bindings** are re-dirtied. T and N1 cover them.
- **Merges made during settling.** S gives the φ merge by cancellation
  (§1a). A rigid tail that appears during settling reaches R through the
  tail pass, whose targets include R. A closed tail that appears then
  leaves R open, which is a harmless gain (N4).

**N2 (precision).** In (b) and (c), and in F2, a clause→R entry's row is
the clause row c itself: its tail t and its counts. `labels(c) + φ_t` is
only the stage that (d) consumes. Building X as `labels(c) + φ_t` and
reading its resolved tail (φ's tail) gives the wrong graph:
- it drops the real edges T_j → c, which arise whenever a T_j's tail is t
  (an installation or a `defer` inside a clause, where the target is c);
- it adds edges on φ.

A positive cycle through such an edge would then go undetected, and the
loop would grow forever. §3.5 already lists "clause own rows" as the
restricted rows, so the literal text is right. Say it next to S.

**3b. Order independence** [read]:
- Every productive step is the mgu step of an equation from a growing
  set: consumptions, φ merges, R ≡ ρ.
- F2's verdict depends only on the invariant cycle sums.
- So the fixpoint substitution, up to renaming, and acceptance do not
  depend on:
  - the drain order;
  - the merge order among three or more handlers. Example:
    P_a = [S Int, S Bool] and P_b = [S ?x] give ?x := Int in both orders;
  - where `sync` runs.

Each eager decision runs after `sync`, so it sees mgu(equations so far).
By 2b that is today's mgu at the same point, restricted to type metas.

**3c. Eager-decision sites** [read, grepped]:
- Handler.purs:117;
- Apply.purs:107 `functionLike`, reached from Call.purs:123,125 and
  Pipe.purs:36;
- Apply.purs:123 `open`;
- Hint.purs:39.

Matrix.purs's `headOf` is a local of patterns. The other uses of resolved
types (Entry, DeferNotes, Failure:167) run at settling or only for
diagnostics.

Postponement is an eager decision inside unification. It is safe:
- undecided keys occur only in a `fail(e)` stage;
- the payload's head is fixed by the time that node consumes it, because
  `sync` ran after the argument node.

## Minor text fixes

- **N4.** §3.4 says "a closed tail closes φ_t". The rev 9 review said
  "leave φ open". Both are compatible (2a gives φ ↦ ∅):
  - closing reproduces today's R exactly, including Go defaulting;
  - leaving it open is a sound gain.

  Record the choice. S's (d) need not repeat it.
- Lines 361–362: sh1 "is rejected today and stays rejected". That is not
  a "change"; reword it.
- Lines 392–393: "The §3.5 loop covers bindings made during settling" is
  fused into the `functionLike` bullet. Make it its own line, or drop it,
  since S states it.
- Line 414: "plus F1's R ≡ R" should read "plus F1′'s φ sharing".

## Ran vs read

- **[ran] today:**
  - accepted, printing `0`: cyc1, cyc1ok, ov1, ov1f, set1, pair1,
    gain1ctl;
  - rejected:
    - cyc2, sh1, cyc3: side-condition E_EFFECT;
    - ov1ctl: E_EFFECT `Unhandled Tick in main`;
    - set1ctl, pair1ctl: `Ambiguous type Opt(_)`;
    - gain1: `Unhandled Cell(Bool) in main`.
- **[read]:**
  - every rev 10 outcome;
  - the N1 divergence trace, and its termination under readings (i) and
    (ii);
  - the embedding (2a) and the pairing-transfer supplement (2b);
  - the bounds and order independence;
  - the code facts in 3a and 3c, from source and grep.
