### Task 6: Specialization: row erasure, effect keys and layout cycles

**Files:**
- Modify: `src/Features/Specialize.purs` (worklist), 
  `src/Features/Specialize/Keys.purs` (effect keys; split if over 250
  lines), `src/Features/Specialize/Body.purs`,
  `src/Features/Specialize/Lower.purs` (rows erased; `THandler` lowers
  to its effect key), `src/Domain/IR/Internal.purs` (`THandler EffectKey`;
  effect table; nodes `HandlerValue`, `Install`, `Perform`, `Handle`,
  `Abort`), `src/Features/Check/Nested.purs` (one graph over types and
  effects), `src/Features/Check/Instantiation.purs` (signature variables
  inside labels)
- Create: `src/Features/Specialize/Effects.purs`,
  `src/Features/Specialize/Unlowered.purs`, `test/fx-specialize.test.mjs`

**Interfaces:**
- §4 "Specialization keys and dependencies": function keys reach body
  keys including effect keys; type keys reach field keys; effect keys
  reach operation-signature keys; `Handler(L …)` reaches L's effect key.
  Every key counts toward the 10,000 limit.
- Nested rule over types and effects (§4 "Layout dependencies"); a
  violation is the existing `NestedDatatype` problem, E_SPECIALIZATION,
  at the nested reference.
- `Features.Specialize.Unlowered.reject ∷ IR.Program → Either Diagnostic
  Unit` replaces `Features.Check.Unlowered` (deleted): `Internal
  "unlowered effect"` for any program with an effect node other than
  `print`.

- [ ] **Step 1: Write failing tests:** recursive handler installation
  yields one function key; growing-label recursion (`a := List(a)`
  through `State(a)`) rejected; `Grow`, the mutual pair and the
  data/effect cycle rejected with exact rows, their bare-parameter
  versions accepted; `State(Int)` and `State(Bool)` give two effect
  keys; rows in data arguments give no extra type key; a pure function
  used at three different rows is one key.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: effect specialization with erased rows
  (FX001)`.

