# Compiler architecture

Five layers, each named for what would make it change (ADR 004, design in
docs/plans/2026-10-07-five-layers-design.md). Imports run only to the same or
an earlier layer; scripts/structure.mjs enforces it from `purs graph`.

| Layer | Modules (src/) | Role |
|---|---|---|
| Domain | Syntax, Type, Resolved, Problem, Host, Checked.Internal, IR.Internal | syntax trees, spans, `Ty v`, resolved syntax, checked IR, monomorphic IR, `Problem` data, capability-port types |
| Features | Resolve, Resolve.{Expression,Types,Pattern,Repeated,Fresh,Lambda}, Check, Check.{Infer,Call,Apply,Lambda,Pipe,Use,Context,Hint,Functional,Arms,Match,Require,Scheme,Walk,Comparable,Instantiation,Nested,Components,Unify,Tables,Inhabited,Signature,Matrix,Usefulness,Missing,Coverage,Search}, Specialize, Specialize.{Seeds,Keys,Lower,Body,Copy,Intern,Values} | resolution, checking, coverage, specialization; report `Problem` data, never text |
| Format | Lex, Parse, Parse.*, Stack, Go, Go.{Layout,Data,Lowered,Expression,Match,Capture,Value,Apply,Lambda,Pipe,Stage,Entry,Compare,Show,Usage}, Diagnostic, Wire, Arguments | text in (tokens, parser, reserved words, uppercase rule); Go out; diagnostic text, `E_*` names, wire records, usage text |
| Runtime | Node (+ Node.js) | port implementations, argv/stdout/stderr/exit, JSON; the only FFI |
| Program | Compile, Command, Main | pure `compile`, commands over any `Host`, entry point |

Domain, Features and Format are pure (core library allowlist, no Effect).

## Pipeline

```text
String -> Lex/Parse -> Syntax -> Resolve -> Resolved
       -> Check: typing per function (unification, comparison groundness,
          inferred-type depth bound) -> checked IR
          -> instantiation rule -> coverage
       -> Specialize -> monomorphic IR -> Go text
```

Every arrow is `Either Diagnostic`. Phase list (P001 final; ADR 007):
Parse, Resolve, Check (typing, instantiation rule, coverage), Specialize,
Go.

Program.Compile composes the phases; Program.Command runs emit/build/run over
the `Domain.Host` ports (records over an abstract monad), so
test/program.test.mjs substitutes fakes. Expected source errors are
`Either Diagnostic`; the first error in phase/traversal order wins. Host
failures (`IoFailure`, `ToolFailure`) are separate values rendered by
Format.Wire.

## Phases

- **Parse** (G001, ADR 006). Format.Parse.Grammar owns `Parser`, a newtype
  whose constructor is not exported, with Functor, Apply and Applicative
  instances only (no Bind, Monad or Alt). Choice is LL(1): `dispatch` picks
  a case by the next token's text without consuming, so error locations
  and messages are those of the hand-written parser it replaced. Grammar's
  `apply` is the only place the remaining input is threaded (the
  `state-thread` regression row restores the defect); Format.Parse.Cursor
  holds the token state and its primitive steps. Every list (`sepBy1`,
  `sepByTrailing1`, `commaList`, `chainLeft1`, `chainRight`, `manyOn`) is
  a `tailRecM` loop, so breadth costs no stack; an arrow type's chain is
  read by `chainRight` and folded right (FN001). `nested`, `infixed`,
  `grouped`, `chainRight` and `rooted` count nesting, and depth past
  `nestingLimit` (128) is E_NESTING. Productions (Format.Parse and
  Format.Parse.{Literal, Pattern, Expression, Declaration, Type, Lambda})
  may not use `do`, `bind` or the Kleisli operators, and only
  Format.Parse imports `run` and `initialState` (CST gate,
  docs/engineering.md).
- **Resolve** has two type passes (register names, assign TypeId/CtorId in
  declaration order; then resolve field and signature types) so mutual
  recursion works. Functions and constructors share one global table. LocalIds
  number parameters, then binders in source pre-order. The counter is
  threaded by Features.Resolve.Fresh, a state-and-error type with Bind (a
  pattern's binders scope its arm body); arms, arguments and pattern fields
  go through Array `traverse`, which is balanced, so resolution depth is
  logarithmic in list length (G001 Task 4).
- **Type table.** `TypeInfo {name, ctors, span}` and `CtorInfo {name, owner,
  fields, span}` travel with the program. Names appear only in messages, never
  in Go.
- **Types.** Domain.Type's `Ty v` (`TInt`, `TBool`, `TData TypeId (Array
  (Ty v))`, `TVar v`) serves each phase with the variables it may hold:
  `Ty VarId` in resolved syntax, `Ty Open` (rigid variable or hole) in the
  checked IR. Its `Monad` bind is substitution. The monomorphic IR has its
  own variable-free `Ty`, so no type variable can reach Go by construction.
  Resolve produces variables and type arguments from source (P001 Task 2;
  `VarId i` is a declaration's i-th parameter or a signature's i-th
  variable).
- **Check** produces the checked IR, Domain.Checked.Internal (`Construct
  CtorId`, `Match`, `Pattern`; each call and construction records its
  instantiation), and is the only producer of `Checked.Program`. Since
  P001 Task 4 each function is checked with a substitution and a meta
  counter threaded through Features.Check.Infer (Features.Check.Scheme
  `State`): parameters are rigid, each use of a function or constructor
  instantiates its scheme with fresh metas, every type equality is a
  unification (Features.Check.Require, whose messages name the whole
  resolved types), comparisons must be ground (Features.Check.Comparable),
  and unsolved metas become holes numbered per function. Every inferred
  type is bounded at 1,000 levels (Unify `inferredTypeLimit`, ruling R7,
  E_NESTING) by an explicit-stack test before anything recurses over it,
  so composed generic calls cannot overflow the stack. Since P001
  Task 5 the instantiation rule (Features.Check.Instantiation, Nested,
  Components; design §4.1) then runs over the whole typed program: inside
  each strongly connected component of the call graph and of the type
  reference graph, every type argument must be a bare variable of the
  referrer or ground (E_SPECIALIZATION). It reports
  E_INTERNAL for invalid
  local/function/type indices; its resolved-syntax input is a trusted phase
  interface, not a hostile-IR validator.
- **Coverage** (Features.Check.Coverage, Usefulness, Missing, Matrix,
  Signature, Inhabited) runs after the whole program type-checks:
  inhabitedness least fixed point (Inhabited, a worklist), Maranget
  usefulness (Usefulness), canonical witness by algorithm I (Missing), over
  the shared pattern-matrix operations in Matrix. Type errors in later
  functions take precedence over coverage errors. Its three linear searches
  (redundancy over arms; exhaustiveness and wildcard usefulness over
  constructors) use Features.Check.Search `firstJust`, a `tailRecM` loop
  (G001 Task 4b); usefulness and algorithm I keep their pending heads and
  witness continuations on an explicit Search `Stack` in a `tailRecM` loop,
  so pattern columns cost no JavaScript stack (G001 final review).
- **Specialize** (Features.Specialize, P001 Tasks 1 and 7) lowers the
  checked IR to the monomorphic IR, Domain.IR.Internal, by whole-program
  specialization (design §6): a first-in first-out worklist seeded with
  every monomorphic type and function in id order copies one function or
  type per key `(declaration, ground arguments)` reached in pre-order.
  Keys are hash-consed (Specialize.Keys: each ground application is
  numbered once as an output type, so a key compares in time linear in its
  arity); holes become a representative (Int; `specializeWith` takes
  another for tests); more than 10,000 keys of polymorphic declarations is
  E_SPECIALIZATION. Monomorphic declarations keep their order and come
  first, so a monomorphic program comes out unchanged
  (test/specialize.test.mjs). Modules: Specialize (API, worklist loop),
  Specialize.Seeds, .Keys (memo tables, limit), .Lower (types, constructor
  fields), .Body (function bodies), .Copy (state-and-failure applicative).
  FN001 Task 5 adds .Intern (arrows hash-consed into the IR's `funTypes`
  table; `IR.Ty`'s `TFun FunTypeId` is a number), .Values (function
  references, constructor owners, lambdas); its temporary guard
  .Unlowered was deleted in FN001 Task 6, when Go lowered function values.
- **FN001 (ADR 008)**: function types are `TFun` in Domain.Type (curried,
  spines walked by loops) and interned `TFun FunTypeId` numbers in the
  monomorphic IR. Format.Parse adds .Type and .Lambda, Resolve .Lambda;
  Check adds .Apply, .Lambda, .Pipe, .Use, .Context, .Hint and
  .Functional (types that can hold a function), and value references are
  instantiation edges; Specialize adds .Intern and .Values; Format.Go
  adds .Value, .Stage, .Entry, .Lambda, .Apply and .Pipe (design §13
  rules 1-8).
  Tests: fn-syntax, fn-names, fn-depth (through Resolve), fn-check,
  fn-rules, fn-hint (Check), fn-specialize, fn-run, fn-timing,
  fn-oracle (+ poly-oracle's staging; generated programs against Go),
  fn-linear, fn-scale.serial; regression rows in
  scripts/regression-fn.mjs with probes in test/regression-fn.mjs.
- **P001 tests** (one file per concern): poly-syntax (grammar,
  resolution), unify (+ unify-oracle, union-find reference), poly-check
  (typing), poly-depth (inferred-type bound), poly-termination
  (+ poly-components; instantiation rule), poly-coverage, poly-run
  (end to end, limit), poly-properties (+ poly-parse, poly-oracle,
  poly-types, poly-expressions, poly-programs, poly-keys; execution oracle,
  uniqueness, determinism, representative independence, §4.2 bound),
  specialize (identity), large-source (3,000 instantiations); phases.mjs
  runs a program through a prefix of the pipeline. Regression rows
  `occurs`, `rigid`, `instantiate` and `spec-key` (test/regression-poly.mjs)
  join the eight earlier ones (docs/engineering.md).
- **Compare** is one expression form, `Compare Operator Expr Expr`, through
  every phase (Operator is a closed Domain ADT); the checker requires equal
  operand types and yields Bool. No target detail enters IR.
- **Go** (Format.Go*) emits one tagged struct per type, constructors, and
  sequential first-match lowering with nil guards. Format.Go.Expression
  threads a per-function match counter (Format.Go.Lowered) and
  Format.Go.Match lifts each match to a top-level `bumpusFn{f}Match{k}` whose
  parameters are its arms' free locals (computed bottom-up with the code;
  Format.Go.Capture), then the scrutinee; lifted functions follow their function in number order (ADR 003
  item 6, E005). Format.Go.Compare emits a
  `bumpusCmpN` per declared type (and `bumpusCmpBool`, decided by
  Format.Go.Usage), Format.Go.Show a `bumpusShowN` per type; `main` prints
  through the latter for declared results (ADR 005). FN001 Task 6 lowers
  function values (design §13 rules 1-8): saturated calls stay n-ary
  (Format.Go.Value); a value of arity n ≥ 2 is a staged wrapper
  `{f}Value`/`{f}Stage{k}` over linked `bumpusNode{N}` environments ending
  in `{f}Entry`, one n-ary call (Format.Go.Stage, .Entry); lambdas are
  lifted to `bumpusFn{f}Lambda{k}` of their free locals then parameters
  (Format.Go.Lambda); applications beyond 64 arguments are split into
  `bumpusFn{f}Apply{k}` helpers (Format.Go.Apply); a pipe whose left
  operand is not a literal or local is lifted to `bumpusFn{f}Pipe{k}`
  (Format.Go.Pipe). Matches, lambdas, pipes and helpers share one counter
  per function. Go representation decisions live here, not in Features.

Only `Features.Check*` and `Features.Specialize*` import
`Domain.Checked.Internal`, and only `Features.Specialize*` and `Format.Go*`
import `Domain.IR.Internal`. These are enforced project boundaries, not
PureScript privacy.

## Verified Go properties

Names are mangled from IDs; no source spelling, timestamp or absolute path
enters output. Emission is byte-deterministic (`bootstrap/answer.go`,
`bootstrap/shapes.go`, `bootstrap/tree.go` snapshots). Int is int32 with
wrapping addition.
Generated code never dereferences nil unguarded (ADR 003). Generated Go is
canonical emitter output; gofmt copies are presentation only.

Lexing and declaration parsing are index-based `tailRecM` loops
(Control.Monad.Rec.Class is allowlisted), so long declaration sequences and
whitespace do not overflow the stack. Since G001, long comma, constructor
and match-arm lists inside one declaration do not either, and nesting
deeper than 128 levels is E_NESTING (ADR 006). Every later phase still
recurses over the tree, which is why the limit exists (heap-based phases
are BACKLOG H001; iterative operator chains O001). Format.Go computes a constructor layout (Format.Go.Layout) once, so
Go emission never searches the type tables per constructor.

## Future stages (proposed, not implemented)

Syntax -> Resolved -> Kinded -> Checked constraints -> coverage/instances ->
Elaborated IR -> lowered Go IR -> emitted Go. A target-neutral
`Features.Lower` is deferred until decision-tree match compilation gives it a
target-neutral job (BACKLOG A002). Foreign values (FFI) need full-value
validation of tag and payload consistency before they become closed sums
(I001). No fake stages for absent features. ADR 002 set the polymorphism
strategy; ADR 007 records the implemented specialization; ADR 008 the
function values and their staged lowering.

## Known leak

Diagnostic offsets are UTF-16 code units, a hosting artifact of JavaScript
strings (ADR 004).
