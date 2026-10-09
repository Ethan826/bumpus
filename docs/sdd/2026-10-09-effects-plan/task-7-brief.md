### Task 7: Go lowering of handlers, operations and failures

**Files:**
- Modify: `src/Format/Go.purs`, `src/Format/Go/Expression.purs`,
  `src/Format/Go/Lambda.purs`, `src/Format/Go/Stage.purs`,
  `src/Format/Go/Apply.purs`, `src/Format/Go/Data.purs`,
  `src/Format/Go/Usage.purs` (`usesContext`), delete
  `src/Features/Specialize/Unlowered.purs` and its Program.Compile call
- Create: `src/Format/Go/Context.purs` (runtime text and mode),
  `src/Format/Go/Effect.purs` (handler structs, perform functions),
  `src/Format/Go/Handle.purs`, `test/fx-run.test.mjs`

**Interfaces:**
- Mode (§4): `usesContext ∷ IR.Program → Boolean` over the emitted IR
  (operation, handler value or type, `with`, `handle`, `fail`). When
  true every function, stage, lambda and function value takes `ctx
  *waxwingCtx` first; otherwise nothing changes.
- Names: handler struct `waxwingEff{N}` (N = effect key index), perform
  `waxwingEff{N}Op{k}`, helpers `waxwingFn{f}With{k}`,
  `waxwingFn{f}Handle{k}`, clauses lifted as lambdas (pre-order, shared
  counter with Match and Block).
- Runtime shapes are Task 1's adopted ones; markers non-zero-sized.

- [ ] **Step 1: Write failing tests** (executable, exact stdout): clause
  context (intercept-and-forward Log, Review Focus 1); targeted abort
  past an inner `handle` (Review Focus 2); nested `State(Int)` and
  `State(Bool)`; generic `constant(v: s): Handler(State(s))`; stateless
  fakes vs real handlers passed as values; `Job(Int, Log + Clock)` in a
  list under two handler sets; a lambda created under one handler run
  under another; a pure `main` beside an unused monomorphic effectful
  function builds and runs (Review Focus 4); every bootstrap snapshot
  byte-identical and Console-only programs without `ctx`.
- [ ] **Step 2: Run** `node --test test/fx-run.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: Go lowering of effect handlers (FX001)`.

