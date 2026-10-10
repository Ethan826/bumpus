# Review: FX001 Task 6 (specialization: row erasure, effect keys, layout cycles)

Base 9a6befd..HEAD, Task 6 paths (review-task6.diff). Focused checks run:
`node --test test/fx-specialize.test.mjs` (18/18 pass at HEAD output/) and a
node probe against output/ for the named finiteness risks (results below).

### Spec Compliance

- ✅ Effect keys (EffectRef, ground args), hash-consed, one worklist with
  `WorkKind = TypeWork | FunctionWork | EffectWork`
  (src/Features/Specialize/Effects.purs:31-67, Keys.purs:75-80, Specialize.purs:108-111).
- ✅ Function keys reach effect keys from operation refs, performs, handler
  constructions, handler types (Handlers.purs:33-113, Lower.purs lowerType THandler).
- ✅ Type keys reach field effect keys (`Handler(L …)` in a field: Lower.purs lowerField/lowerHandler);
  effect keys reach operation param/result keys (Lower.purs fillEffect/layout). Test "effect keys reach operation types; handler fields reach effects".
- ✅ Rows erased: lowerType/lowerField ignore TData rows and arrow rows; labels only in rows make no key (test "rows in data arguments give no extra type key"; probe `rowOnly` accepted).
- ✅ 10,000 limit: effect keys claim only with type arguments (Effects.purs:46), per ruling F5.
- ✅ Console/Fail handler types get layouts with no operations and no work item (Effects.purs:59-61), per ruling F3.
- ✅ Nested rule over one graph of types and effects (Check/Nested.purs nestedTypes/edges/layoutReferences/judgeField); `Handler(L …)` edges to L; rows no edge; violation is existing NestedDatatype / E_SPECIALIZATION at the nested reference. Grow, mutual pair, data/effect cycle rejected with exact text and message; bare versions compile.
- ✅ Finiteness probes beyond the tests (node probe at HEAD): handler type inside an operation-parameter arrow (`fn give(f: Int -> Handler(P(Box(a))))`) rejected; Fail payload growth in a field (`T(Handler(Fail(T(Box(a)))))`) rejected; Fail payload crossing effect/data (`G -> Fail(Error(G2(a))) -> G(Box(a))`) rejected; handler inside a field arrow rejected; `Handler(G(Box(a)) with pure)` rejected. `Parts.children` includes handler label arguments, so Fail payloads are edges.
- ✅ Rule A: growing-label recursion rejected by Instantiation unchanged ("Recursive call to r changes its type arguments"); the plan's listed Instantiation.purs change was indeed unnecessary (no diff to that file; test passes).
- ✅ Guard: Features.Check.Unlowered deleted; `Features.Specialize.Unlowered.reject ∷ IR.Program → Either Diagnostic Unit` after specialize (Program/Compile.purs:14); any effect layout or any OperationRef/Perform/HandlerValue/Install/Handle/Abort node → Internal "unlowered effect". Every THandler implies a layout, so handler types anywhere (fields, params, locals) are caught; `children` covers every non-effect node with subexpressions.
- ✅ Fail family = declared head (Parts.typeHead → HeadData TypeId), so Error(Int)/Error(Bool) share; using the checked payload type is sound because a rigid/unsolved head is already E_TYPE (design §2 "Label keys").
- ✅ `mentionsTypeVariable` (Parts.purs) seeds: a signature variable only in the function's own row labels makes it polymorphic; row tails ignored. Holes in rows cannot occur in a non-main signature (rigid rows) and main's row is restricted to Console, so no misclassification found.
- ✅ Key ordering deterministic (counter-indexed Maps; specializationKeys types, effects, functions in output order).
- ✅ Allowlists respected (Nested: Check*; Handlers/Unlowered: Specialize*; Format.Go.Data: Format.Go*). Style: files ≤ 232 lines, lines ≤ 80 chars, where-binding counts ≤ 8.
- ✅ Required tests from brief Step 1 all present (test/fx-specialize.test.mjs).
- ⚠️ `npm run verify` at final HEAD: report says the full verify ran at 85c5867 (before the parser fix) and regression-proof rerun is "in progress"; cannot verify from diff. bootstrap byte-identity likewise not verified here (Go changes only add THandler cases and an unreachable catch-all, so plausible).
- ⚠️ TDD: 3 of 18 tests (growing-label, rows in data args, guard) passed before the change; accepted as characterization under ruling F12.

### Strengths

- Nested and Lower walk resolved types beside source with the same `handlerLabelRef`, so the graph's edges are exactly the worklist's dependencies, as the spec demands; offences land at the nested reference.
- The guard is moved over emitted IR with a simple completeness argument (layout ⇔ handler type/operation/handler), and the regression row was re-targeted rather than dropped.
- Seeds bug fix (variable only in `with State(a)`) is covered by a test.
- poly-keys helper fixed to build failure messages lazily (avoids the 5,000-parameter stack overflow).

### Issues

Critical: none.

Important: none.

Minor:
1. src/Format/Go/Expression.purs:58 and src/Format/Go/Usage.purs:41,64 — wildcard `_`/`effect`/`other` arms swallow every future Node constructor, losing exhaustiveness warnings for Task 7. Fix: list the six effect constructors explicitly.
2. test/fx-specialize.test.mjs guard test — no case for a bare `OperationRef` (e.g. `let f = now;`) or a handler type held only by a function parameter; the guard covers them by construction, but a one-line case each would pin it. Fix: add two `unlowered(...)` lines.
3. src/Features/Specialize/Lower.purs (lowerType/lowerHandler) — `>>= (pure <<< IR.THandler)` is `map IR.THandler`. Cosmetic.
4. Fail layouts are keyed by the full payload (`(Fail, [Error(Int)])`), while the spec's runtime key is `(Fail, TypeId of Error)`. Fine as a layout identity, but Task 7 must not treat the layout key as the runtime lookup key. Note it in the Task 7 brief.
5. specializationKeys omits Console/Fail layouts (no work item), though they claim the limit when they have arguments. Tests can't see them. Acceptable; mention in the comment at Specialize.purs specializationKeys.

### Assessment

Task quality: **Approved**. The implementation meets §4's key, dependency, erasure and layout-cycle rules and the rulings. Probes of the named finiteness risks (operation-parameter arrows, Fail payloads, data/effect crossings) are all rejected correctly. The remaining items are minor hardening; the only open item is the final-HEAD verify/regression-proof evidence.
