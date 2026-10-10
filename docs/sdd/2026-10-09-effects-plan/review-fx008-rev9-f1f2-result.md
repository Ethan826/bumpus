# Focused review: FX008 revision 9, the one-way hook's F1, F2 and `sync`

Subject: docs/plans/2026-10-10-abort-tracking-design.md rev 9, §3.4
"One-way hook" (F1, F2, `sync`) together with §3.5 steps 1–3. D0–D7 were
not reopened. Read with review-fx008-rev8-hook-result.md,
review-fx008-termination-result.md, review-fx008-rev7-result.md, and with
Subst.purs, Binding.purs, UnifyRow.purs, Unify.purs, Consume.purs,
Handler.purs, Apply.purs, Scheme.purs and Check.purs. No repository file
other than this one was changed.

Tags: [ran] means run on the current compiler (`node scripts/waxwing.mjs
run`). [read] means reasoning about rev 9, which is not implemented. New
probes are in
/private/tmp/claude-501/-Users-ethan-Desktop-waxwing/d41c2ee4-6993-4bc5-a1f7-33359afc9a21/scratchpad/rev9/.

## Verdict: substantive issue (three defects, each with a small correction)

| Property | Verdict |
|---|---|
| 1. Termination | REFUTED as written (cyc1 loops on renames); ESTABLISHED WITH CORRECTION |
| 2. Inference compatibility | REFUTED as written (F1 over-restores: ov1); ESTABLISHED WITH CORRECTION. Marks: ESTABLISHED, provided the loop's c→R consumption is mark-free |
| 3. Scheduling | REFUTED as written (F1 never runs for tails merged during settling: set1); ESTABLISHED WITH CORRECTION |

The worry raised in the brief about the order F2 → F1 → consume is real,
but it is not where divergence comes from (see 1b). No unsound acceptance
was found. Every defect either rejects programs that are accepted today,
or hangs.

## 1. Termination

**1a. As written, `sync` diverges on a satisfiable zero-weight cycle.**

Take cyc1.wxw (rev8 probe). It is accepted today and prints `0` [ran],
as is cyc1ok:
```
let k = fn(u: Unit) => ();
let h = handler Tick { tick() => { log(1); k(()) } };
let g = fn(u: Unit) => { k(()); with h { tick() } };
```
Rev 9 trace [read]:
- After `with h`, R ≡ ρ_g, so c = [Log | x] and R = [Log | x]. That is a
  self-loop c→R with w_Log = 0, so F2 allows it.
- The hook consumes `[Log] + f` (f fresh) into R. Log matches.
- Then `unifyTails` binds the larger meta to the smaller (UnifyRow.purs
  `unifyTails`). The newest fresh meta is always the smallest, so it
  binds x := f.
- x is c's watched resolved tail, so `bindTail` marks it dirty and moves
  the watch to f.
- The next drain repeats this with f := f′, and so on.

No label count ever changes. Only the tail is renamed.
- If `sync` drains to a fixpoint, it hangs.
- If it makes one pass per call, `dirty` is never empty, and every later
  `sync` does a useless consumption.
- The one-pass reading has a second defect: a cascade of depth 2 or more
  (c1→R1, where R1's tail is c2's, then c2→R2→ρ) is only half done when an
  eager decision reads it.

The §3.5 loop does not have this defect, because its exit test counts
labels, not bindings.

**1b. Cycles exposed by F1 cannot escape F2 for more than one step** [read]:
- F1 is one finite unification, and so is the consumption that follows
  it.
- After R_i ≡ R_j, both rows share a tail and grow only there, so they
  stay equal. Any cycle that passes through the equality is then an
  ordinary c→R feed edge on resolved tails.
- F2 is re-run before each consumption on the current graph, and a cycle's
  sum is invariant (termination review 4b). So at most one unchecked
  consumption follows each F1 merge before the positive cycle is reported.
  Every later consumption is checked.
- Example: R_j ≡ ρ_g with ρ_g's tail = c_i's tail, then F1 R_i ≡ R_j.
  After one extension, the next F2 sees a self-loop with w = 1 > 0.
- Cost: the error can surface one step late, under a different headline
  (say a payload mismatch met first). Acceptance is unchanged.
- Reordering to F1 → F2 → consume removes even that step.

**1c. Correction T.** Run each clause row only when its *signature* has
changed:
- The signature is its per-key label counts, plus its resolved tail's
  kind and class (class representative, rigid variable, or closed).
- Record the signature at each hook consumption. A dirty row whose
  signature is unchanged is dropped from `dirty`. A rename does not change
  the signature.
- `sync` iterates until no row's signature differs, in the order: class
  bookkeeping and F1 (the corrected F1′ in §2), then F2, then the
  consumption.

**Measure** [read]:
- Every productive step either raises some clause row's Σ counts or
  changes some row's tail class or kind.
- Class merges, from F1 or from arguments, and rigid or closed bindings
  remove an unbound class. So there are at most N0 + n_c epochs, where N0
  is the number of unbound classes and n_c the number of clause rows.
- Within an epoch, the growth is Bellman–Ford relaxation on the c→R
  graph with V ≤ 2n_c classes, and F2 excludes positive cycles. That gives
  at most V + 1 sweeps, each of at most n_c consumptions.
- Bound per `sync`: (N0 + n_c + 1)(2n_c + 1)·n_c consumptions, each one
  finite unification.

**Interleaved with §3.5:**
- `sync` runs at most once per inferred node plus once per eager-decision
  site. Each run terminates, so checking terminates.
- Settling is the loop, with its bound (N0 + 1)(2n + 1) + 1 rounds plus
  the pairs (a) decides.
- Correction S (§3) adds F1′ to the loop. F1′'s φ merges are class merges
  and create no class, so the epoch count and the bound are unchanged.

## 2. Inference compatibility

**2a. F1 as written over-restores and changes acceptance.**

Today R_i *is* c_i. Two clause rows that share a resolved tail t are
P_i + t and P_j + t, which share a tail but are not equal. F1 imposes
R_i ≡ R_j, which today lacks whenever P_i ≠ P_j.

ov1.wxw has no `defer`. It is accepted today and prints `0` [ran], and so
is ov1f, with the handlers in the other order:
```
effect Log { fn log(n: Int): Unit; };
effect Tick { fn tick(): Unit; };
fn main(): Unit with Console = {
  let k = fn(u: Unit) => ();
  let h0 = handler Tick { tick() => () };
  let h1 = handler Log { log(n) => with h0 { k(()) } };   // c1 = [| t], T = [Tick | t]
  let h2 = handler Log { log(n) => k(()) };               // c2 = [Tick | t]
  with h1 { log(1) };
  print(0)
};
```
Today R1 = [| t] and R2 = [Tick | t], and `with h1` binds t := Console.

Rev 9 [read]:
- c1 and c2 resolve to the same tail, so F1 gives R1 ≡ R2 ∋ Tick.
- `with h1` under main's closed row then fails, because Tick is extra.
- ov1ctl, with R1 ∋ Tick forced, is rejected with E_EFFECT `Unhandled Tick
  in main` [ran].
- Without F1, rev 9 accepts ov1.

**2b. Correction F1′: a shared remainder per tail class, replacing
"R_i ≡ R_j".**
- Keep a row meta φ_t for each unbound clause-tail class representative
  t.
- The hook, and loop step (d) for clause→R entries, consume every clause
  row of the class as `labels(c) + φ_t` into its R, instead of using a
  fresh tail.
- When two classes merge, unify φ_t1 ≡ φ_t2 (mark-free).
- On t := L + t′, let φ_t′ be fresh. The next consumption binds φ_t to
  L° + (…φ_t′) by first occurrence.
- On t := ϱ, bind φ_t := ϱ (this is M2). On a closed t, leave φ open.
- This makes R_i = P_i° + φ and R_j = P_j° + φ, which is exactly today's
  shape.
- For two1, two2, two3 and two1f (P_i = P_j = ∅), it coincides with F1.
- For ov1 it gives R1 = [|φ], so ov1 is accepted.
- Apply it to all clause rows of the class, the same handler's clauses
  included. Then sh1.wxw keeps today's rejection (`... and Tick + ...
  cannot be made equal`) [ran today].
  - Rev 9 as written accepts sh1 [read]. It applies F1 only across
    handlers, and per-clause rows lose today's c_a ≡ c_b.
  - Sound, but an unlisted gain. Restricting F1′ to different handlers is
    also sound, but sh1 must then be listed in §6.

**2c. Why F1′ creates no equality that today lacks (embedding)** [read]:
- Map rev 9 to today: c ↦ today's R, R_i ↦ R_i, φ_t ↦ t.
- Rev 9's equations, ignoring marks, then become:
  - the clause and body equations, which are today's, with c for R;
  - R ≡ ρ, which is today's;
  - `labels(c) + φ_t ≡ R`, which holds in today's solution because
    today's R is c = labels + t;
  - φ merges and extensions, which mirror today's t bindings.
- So today's mgu induces a solution of rev 9's system. Rev 9 with F1′
  then cannot reject a program that today accepts through a unification
  failure, a side-condition error, or an F2 positive cycle. A finite
  solution exists, so no cycle has positive weight.
- This also proves rev 8's "[read; not proven]" claim that F2's positive
  cycles coincide with today's rejections.
- What remains is the deliberate one-way loss (labels reach φ, not t). It
  can only leave rev 9 more general: an unsolved meta, or a different
  defaulted layout in Go. This is rev 8's argument and probes, not re-run
  here.
- F1 as written fails this embedding exactly when P_i ≠ P_j, which is
  ov1.

**2d. Marks** [read]. No mark is identified with an R mark by binding:
- F1/F1′, the hook and R ≡ ρ unify with marks ignored.
- Labels added by extension get fresh marks with no edge.

Sharing by identity does occur:
- After R ≡ ρ, labels that later reach the shared tail are the same
  objects in R and ρ.
- F1 joins R_i's class to R_j's, so ρ_i and ρ_j share. This is L4's third
  source, already recorded.
- That sharing is harmless only if nothing ever reads a mark through R.

One text gap:
- §3.5 (d) consumes *every* restricted row "directionally (target ⊑ row)",
  and the clause→R entry is one of them.
- Through R1 ≡ R2 ≡ ρ2, that imposes ρ2-mark ⊑ c1-mark, from a context
  where h1 is never installed. That edge is spurious: sound, but it can
  reject a `defer` under h1's clauses.
- Fix: state that (d)'s consumption into R ignores marks, as the hook's
  does.

With that fix, R's marks are never read, and C's and ρ's marks get edges
only from C's consumption, the frame constraints and call sites.

## 3. Scheduling

**3a. Bindings outside `bindTail`/`extendRow`: none** [read]:
- Row bindings are inserted only in Binding.purs `bindTail` and
  `extendRow`.
- `Subst.compose` has no caller outside the re-export in Unify.purs.
- Type-meta bindings change no label count. R's copies share argument
  terms with c's labels, so they see those bindings directly.
- Postponed pairs revert to `operands.start`, which drops `dirty` and the
  watch moves along with the bindings.
- Rows acquire labels only through key-decided steps (`consume` and
  `finish` postpone on an unknown key), so the hook's own consumption is
  never newly postponed relative to today.

**3b. Meta-to-meta merges** [read]:
- Of two watched representatives, `unifyTails` binds exactly one, so the
  merge is seen.
- An unwatched meta bound to a watched one creates no obligation.
- `sync` needs a table from representative to clause rows to find F1/F1′
  partners. That is an implementation note.

**3c. Bindings made during settling: F1 is missed.**

§3.4 says "the §3.5 loop covers bindings made during settling", but the
loop has no F1. set1.wxw has no `defer`. It is accepted today and prints
`0` [ran]:
```
type Opt(a) = No | Some(a);
type Job(a, ...effects) = Job(Int -> a with ...effects);
effect Log { fn log(n: Int): Unit; };
effect Cell(a) { fn put(x: a): Bool; };
fn main(): Unit with Console = {
  let k1 = fn(n: Int) => ();
  let k2 = fn(n: Int) => ();
  let h1 = handler Log { log(n) => k1(n) };
  let h2 = handler Log { log(n) => k2(n) };
  let g1 = fn(u: Unit) => with h1 { let v = No; if put(v) then print(v == v) else () };
  let g2 = fn(u: Unit) => with h2 { if put(Some(true)) then () else () };
  let r = fn(x) => { fail(Job(k1)); fail(x) };
  let q = fn(u: Unit) => r(Job(k2));
  print(0)
};
```
- `fail(x)` is postponed, because x's key is unknown. The retry in loop
  step (a) matches `Fail(Job(Unit, T1))` and so unifies T1 ≡ T2, which are
  the tails of c1 and c2. The merge therefore happens during settling.
- Today R1 and R2 then share a tail, so `Cell(Opt ?b)` meets
  `Cell(Opt Bool)`.
- Rev 9 [read]:
  - g1's and g2's Cell labels went into R1's and R2's own tails;
  - the loop's (d) consumes the empty c1 and c2 into R1 and R2, which
    adds nothing;
  - result: `Ambiguous type Opt(_) in comparison`.
- set1ctl.wxw passes a fresh lambda instead of k2, so the merge never
  happens. It gives exactly that error [ran].

This is also order dependence: the same merge made during checking would
have been linked. **Correction S:** loop step (d) consumes clause→R
entries with F1′ (the φ of the current class), or equivalently runs F1
each round.

**3d. Sync's own bindings** go through `bindTail` and `extendRow`, so they
are re-dirtied. That includes renames, which is 1a; Correction T fixes
it. `sync` must iterate to a fixpoint (1a, cascades).

**3e. Order** [read]. After Corrections T, F1′ and S:
- every productive step is the mgu step of an equation from a monotone
  set: consumption, φ merges, and R ≡ ρ;
- F2's verdict is invariant (cycle sums never change).

So the substitution at each fixpoint, and final acceptance, are
independent of three things:
- the order in which tails are drained;
- the order of φ merges among three or more handlers (unification is
  order-free, and Leijen's is complete);
- where `sync` runs between eager decisions.

Only the diagnostic headline can vary; fix it by source order.

**3f. Eager-decision sites** [read]:
- The `Scheme.headOf` callers are Handler.purs:117, Apply.purs:107
  (`functionLike`, reached from Call.purs:123,125 and Pipe.purs:36),
  Apply.purs:123 (`open`, from Apply.purs:80,99) and Hint.purs:39.
- `functionLike` is a pure `State → Boolean`, so `sync` must run in its
  callers. Matrix.purs's `headOf` is local to patterns and is not one of
  these sites.
- The list in §3.4 is complete if "Apply's functionLike" includes the
  Call and Pipe callers.

**3g. Cost** [read]. F2 must search only from dirty rows: a DFS over c→R
edges whose R tail is a clause tail. A global cycle test at every `sync`
would cost O(n_c) per node, which breaks T003 linearity.

## Smallest corrected procedure (replaces F1 and the hook's "fresh tail")

A `sync` iteration repeats while some clause row's signature (per-key
counts and tail class or kind) differs from the one recorded:
1. Re-index clause rows by resolved tail. On a merge of classes t1 and
   t2, unify φ_t1 ≡ φ_t2, mark-free (F1′). On t := ϱ, bind φ_t := ϱ.
2. F2: run (c)'s per-key test on the c→R edges reachable from the changed
   rows. A positive sum gives the side-condition error.
3. Consume `labels(c) + φ_t` into R, mark-free, and record the signature.

Loop step (d) uses the same φ_t for clause→R entries, and is mark-free.

## Ran vs read

- [ran] today:
  - accepted, printing `0`: ov1, ov1f, set1, cyc1, cyc1ok;
  - rejected: ov1ctl (E_EFFECT Unhandled Tick), set1ctl (Ambiguous
    `Opt(_)`), sh1 (side-condition E_EFFECT).
- [read]:
  - every rev 9 outcome: the cyc1 rename loop, ov1 rejected under F1,
    sh1 accepted, set1 rejected;
  - the faithfulness of the ctl emulations;
  - the embedding argument, the bounds, order independence;
  - the code facts in 3a and 3f, read from source.
