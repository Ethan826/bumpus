# Task 6 report (implemented inline by the controller; commits 2501024, a3b54d3, 85c5867)

## Implemented
- IR (Domain.IR.Internal): `THandler EffectKey`; `EffectKey` newtype; program table `effects ∷ Array EffectInfo` ({effect ∷ EffectRef, name, arguments, operations, span}); nodes `OperationRef EffectKey Int` (bare operation as a function value; not in plan text — ruling F2), `Perform EffectKey Int (Array Expr)` (partial like Call), `HandlerValue EffectKey (Array Clause)`, `Install Expr Expr` (with), `Handle Expr (Array FailClause)`, `Abort TypeHead Expr` (fail); FailClause carries `family ∷ TypeHead` (declared head; Error(Int)/Error(Bool) share). `effectParts` helper.
- Keys: `WorkKind = TypeWork | FunctionWork | EffectWork` replaces `function ∷ Boolean`; State gains effectKeys/effects/counts.effects; `claim` exported.
- Features.Specialize.Effects.effectAt: effect layout key (EffectRef, ground args), hash-consed, created on first reference; claims the 10,000 limit only with type arguments (ruling F5); user effects enqueue EffectWork; Console/Fail layouts (handler types only) have no operations and no work item (ruling F3).
- Lower: `THandler` lowers label args then effect key; `lowerField` handles handler types in fields beside their label syntax (Domain.Syntax.handlerLabelRef handles both `Handler(L(..))` NamedRef and THandlerRef forms); `fillEffect` lowers each operation's parameter and result types beside their syntax (Resolved.OperationInfo gains `syntax`), so effect keys reach type keys and effect keys of handler types in operations.
- Body delegates effect nodes to Features.Specialize.Handlers (layout from instantiation; clauses' params typed at key; Abort/Handle family from Parts.typeHead of the checked payload type; missing head = Internal "Fail without a family").
- Seeds: monomorphic = no type variable anywhere in params/result/own row labels (Parts.mentionsTypeVariable; row tails ignored) — fixes a crash ("Invalid type variable") for a function whose type variable appears only in `with State(a)`.
- Specialize: worklist dispatch on kind; program `effects` output; `specializationKeys` lists types, effects, functions with `effect` flag; groundType handles THandler.
- Check.Nested: one reference graph over types (0..n-1) and effects (n..): edges from ctor fields and operation param/result types; `Handler(L …)` edges to L; rows (labels in rows) are no edge; rejection is existing NestedDatatype at the nested label reference.
- Guard: Features.Check.Unlowered deleted; Features.Specialize.Unlowered.reject over IR after specialize (Program.Compile): Internal "unlowered effect" if any effect layout exists or any OperationRef/Perform/HandlerValue/Install/Handle/Abort node. Unused declared effects now compile (no layout, no node).
- Format.Go: THandler → `*waxwingEff{N}` placeholder name; Compare/Show treat THandler like TFun (never compared/printed); Expression lowers effect nodes to a panicking placeholder (unreachable behind the guard; Task 7 replaces); Usage walks effectParts.
- Tests: test/fx-specialize.test.mjs (18). test/poly-keys.mjs helper: message built only on failure (was a stack overflow at 5,000-parameter keys on this machine), names effect keys, Unit, Handler types. fx-signature unused-effect test now expects success; regression row handler-metadata re-targeted to Specialize/Unlowered (proof passes); poly-run/specialize tests expect effect:false / effects == [].

## TDD evidence
RED: `node --test test/fx-specialize.test.mjs` before src changes: 15/18 fail (.build/fx001-task6-red.log); tests 2 (growing-label rejection, already enforced by Instantiation since labels' variables are signature variables), 14 (rows in data args) and 17 (guard) passed before — characterization tests (ruling F12).
GREEN: 18/18 after (test 10 required the Task 5 parser fix 5da7865/3aa1217 and a `with pure` handler result row).
Full verify .build/fx001-task6-verify.log (at 85c5867, before parser fix round 1): build 0 warnings, gates pass, 752/752 parallel tests; serial 13/22 — 9 timing failures reproduced identically on pre-Task-6 baseline 9a6befd (BACKLOG T007). Regression proofs: rerun in progress.

## Concerns
- Plan lists `src/Features/Check/Instantiation.purs (signature variables inside labels)` as modified: no change was needed (test 2 passes); verify that claim.
- Effect keys are not seeded for monomorphic effects (on demand only).
- Specialize.Keys is now 232 lines.
