# Review: FX001 Task 7 (49717bc..e9a613f)

### Spec Compliance
- ✅ Mode over emitted IR (`usesContext`, src/Format/Go/Context.purs:28): any layout or any of the six nodes; Console-only and unused-generic programs emit no ctx; unused monomorphic one forces ctx and runs (fx-run cases, Review Focus 4).
- ✅ Uniform `ctx *waxwingCtx` first in functions, stages, lambdas, lifted match/block/pipe/apply helpers, fun types; `main` gets `nil`. Constructors also take ctx (risk b): consistent with "every function value", harmless on direct calls.
- ✅ Clause context = outer at the `with`: perform calls the clause with `frame.outer` (Effect.purs `perform`). Review Focus 1 tested, also with the forwarding handler passed as a value. Probe: a three-deep forwarding chain gives 12 as expected.
- ✅ Targeted abort (Focus 2): clause fail skips the inner `handle` (fx-run case 3). Probe: the same with the handler passed as a value gives 2.
- ✅ Markers `struct{ id uint64 }` (non-zero-sized), fresh per family per activation. `recover` sits directly in the deferred func of `waxwingHandle`, consumes only its own markers and re-panics everything else. The clause runs after the return, in the `handle`'s ctx.
- ✅ F1: Fail key = `failKey TypeHead` (Handle.purs `lowerAbort`/`frames`), not the layout. F2: OperationRef is lowered through the staged wrapper and counts in usesContext. F3: empty structs (test asserts `type waxwingEff0 struct {\n}`). F7: `panic("no handler for L")`. No defer/crash emitted.
- ✅ F4: every 'unlowered effect' assertion is replaced by run-with-exact-stdout or Right+struct text, so each one is stronger. Unlowered.purs and its Compile call are deleted. Expression/Usage wildcards are replaced by explicit arms.
- ✅ No bootstrap/*.go file is touched. The IR allowlists are unchanged (no new Domain.*.Internal importers outside Check*/Specialize*/Format.Go*).
- ❌ Clause order within one `handle`: Handle.purs:117-125 makes the LAST clause innermost. Typing (§2: body checks against `Fail(E1) + … + ρ`, first occurrence wins) makes the FIRST clause the innermost one. See Critical.
- ⚠️ Whether the two checker fixes' tests fail without each fix was not re-run by me. The report claims it only for the end-to-end case, and the verify notes mention a revert of Consume only.

### Strengths
- Runtime matches §4 closely: immutable ctx list, no pop, the generic `waxwingHandle[R]` returns `(result, abort)`, and recovery is precise.
- `with` evaluates `h` at the call site before the helper runs, which keeps strict order. `fail` evaluates its payload first.
- The test set covers every brief item with exact stdout, plus useful extras: partial operation call order, operation as a value, recursive install, handlers in data, staged/match/pipe/block threading. The report's mutant evidence is relevant. The focused run is clean: 22/22 with no noise.
- Both checker fixes are small and correct. `ownerType` removes duplication between construction and patterns. Consume resolves only the 1-row arrow before choosing closed/opened, which is the right test.
- The regression row `effect-free-ctx` targets a real Task 7 defect (ctx mode for any program). The block-order needle update keeps that row meaningful.

### Issues
**Critical**
- src/Format/Go/Handle.purs:117-125 (`frames`, foldl): when two clauses of one `handle` share a family key, the last clause is pushed innermost, but the checker types the body against the first. Probes:
  - `type Error(a) = Error(a); fn main(): Int = handle fail(Error(5)) { fail(e: Error(Int)) => match e { Error(n) => n }, fail(e: Error(Bool)) => 2 };` type-checks, then crashes at run time with `panic: interface conversion: interface {} is main.waxwingTy0, not main.waxwingTy1`. A well-typed program crashes.
  - `handle fail(3) { fail(e: Int) => e, fail(e: Int) => 2 }` prints 2. The typing, and match-like reading order, select the first clause (3).
  - Fix: push frames so that clause 0 is innermost (fold from the right, or reverse the array) and fix the comment. Add both probes to fx-run with exact stdout (5, 3). Alternatively, if duplicate families are meant to be illegal, reject them in the checker, but the Error(Int)/Error(Bool) pair is legal per §2.

**Important**
- None beyond the above.

**Minor**
- src/Format/Go/Context.purs:44-57: `children` copies the deleted guard's traversal with a `_ → []` wildcard. A future node (Task 8 defer/crash containers) would silently fail to select the mode. List the arms explicitly, or reuse one shared traversal.
- src/Format/Go/Handle.purs:62-64: `handlerKey _ → EffectKey 0` silently picks layout 0 for a non-handler type. Lowered.purs `effectShape` likewise falls back to key 0. These are compiler-bug paths that emit wrong Go rather than a guard.
- Context.purs `waxwingFail` reports `no handler for Fail`. F7 asks for `<L>`, so `Fail(<family>)` would be more useful (Task 8 formats it).
- Checker fixes (Tables.ownerType / Match, Consume) are covered only by one end-to-end Go case. Add check-level tests: a pattern on a row-parameterized constructor, and a call through a field whose row tail is a bound meta. Show that each fails with its fix reverted, in an isolated copy (AGENTS.md).
- Context.purs `runtime` is one ~60-line declaration (budget aim of 30). It is acceptable as data text but could be split, e.g. lookup vs handle.

### Assessment
Task quality: **Needs fixes** (one Critical: clause/frame order in multi-clause `handle` contradicts typing and crashes a well-typed program).
