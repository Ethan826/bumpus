# First-class functions, lambdas and closures: design (FN001)

Status: direction settled with the user 2026-10-08 (curried semantics with
Algol-like multi-argument syntax; lambdas `fn(x) => body`; `|>` in scope;
no local binding form). First draft reviewed by the user 2026-10-08:
revise before approval (canonical uncurried representation lost
evaluation timing); this revision replaces it with staged nested function
values and records the user's answers to the open questions (section 12
maps each finding to its resolution). Approved by the user 2026-10-08.
Nothing is implemented. Amendment A1 (section 13,
from a measurement made while writing the plan) changes how staged
values are lowered, not what they mean; its architecture was approved
2026-10-08, its linked representation awaits measurement. The plan is
docs/plans/2026-10-08-functions-plan.md.

## Goal and non-goals

Goal: functions as values. Function types, partial application, passing
and returning functions, anonymous functions that capture variables, and
reverse application, so that `map`, folds and pipelines can be written
once and specialized like any other generic function (ADR 007):

```
fn map(f: a -> b, xs: List(a)): List(b) = match xs {
  Nil => Nil,
  Cons(x, rest) => Cons(f(x), map(f, rest)),
};
fn main(): List(Int) = Cons(1, Cons(2, Nil)) |> map(fn(x) => x + 10);
```

Non-goals: a local binding form (its own backlog item); a Unit type and
zero-parameter lambdas; result-type annotations on lambdas; `_` as a
named function's parameter; placeholder application such as
`take(_, xs)`; default, variadic, overloaded-by-arity or named parameters;
`>>`/`<<` (Prelude functions once a Prelude exists, C001); rank-2 or
polymorphic lambdas and polymorphic fields; foreign Go functions (I001);
comparing or printing functions; optimizing saturated application of
function values (section 7).

Preserved: phase boundaries and both IR allowlists; strict evaluation; the
structural order and print format of ADR 005; every existing diagnostic
not listed in section 9. A program that uses no function type, lambda,
function value, partial application or `|>` emits byte-identical Go
(bootstrap/*.go unchanged), and saturated direct calls of named
functions keep today's Go in every program.

## 1. Syntax

```ebnf
type        = arrow ;
arrow       = operand, [ "->", arrow ]
            | "(", type, ",", type, { ",", type }, ")", "->", arrow ;
operand     = "Int" | "Bool" | lower
            | upper, [ "(", type, { ",", type }, ")" ]
            | "(", type, ")" ;
expression  = "if", expression, "then", expression, "else", expression
            | "match", expression, "{", arm, { ",", arm }, [ "," ], "}"
            | "fn", "(", lparam, { ",", lparam }, ")", "=>", expression
            | pipeline ;
lparam      = ( lower | "_" ), [ ":", type ] ;
pipeline    = comparison, { "|>", comparison } ;
atom        = primary, { "(", [ arguments ], ")" } ;
primary     = integer | "true" | "false" | identifier
            | "(", expression, ")" ;
```

- New tokens `->` and `|>`, matched longest first (`->` before the minus
  of an integer literal, `|>` before `|`). No new reserved word: `fn`
  followed by `(` is a lambda; at declaration level `fn` is still
  followed by a name.
- `->` is right-associative and binds loosest in types:
  `Int -> Int -> Int` is `Int -> (Int -> Int)`. `(A, B) -> C` is notation
  for `A -> B -> C`, exactly; `(A) -> B` is `A -> B`. A parenthesized list
  of two or more types not followed by `->` is E_SYNTAX `Expected ->`;
  `() -> A` is E_SYNTAX `Expected a type` at `)`.
- Nesting (ADR 006, E_NESTING): an arrow's parameter side is one level
  deeper than the arrow; its result side is not. So `(Int -> Int) -> Int`
  nests two levels and `Int -> Int -> … -> Int` of any length one level.
  The same measure applies to the inferred-type bound (section 3), so a
  declaration's parameter count never counts as depth. An arrow chain is
  parsed iteratively, not by one recursion per `->`.
- A lambda, like `if` and `match`, extends as far right as possible and
  must be parenthesized as an operand: `f(fn(x) => x)` needs none (an
  argument is an expression), `(fn(x) => x)(1)` does.
- `|>` binds looser than comparison and is left-associative:
  `xs |> take(3) |> length` is `(xs |> take(3)) |> length`. Neither
  operand may be an unparenthesized `if`, `match` or lambda.
- Application is postfix and repeatable on any primary: `f(1)(2)`,
  `(g)(x)`, `make()(x)`. `f()` with no arguments is allowed only on a
  named zero-parameter function (section 4).
- A function's span is unchanged; a lambda spans `fn` through its body;
  a pipeline spans its left operand through its right; an application
  spans its callee through its closing parenthesis.

## 2. Names

The bare-name rules of docs/language.md change as follows; the rest stay.

| Name in expression | Bare | Called `n(…)` |
|---|---|---|
| local (parameter, binder, lambda parameter) | its value | applies its value |
| function with parameters | a function value | a call (section 4) |
| function with no parameters | E_ARITY `Expected f()` (new) | a call |
| constructor with fields | a function value | a construction (section 4) |
| nullary constructor | a value (unchanged) | E_NOT_CALLABLE (unchanged) |

- Locals shadow globals, as today. A lambda parameter shadows anything of
  the same name in the lambda body. Named lambda parameters must be
  distinct (E_DUPLICATE `Duplicate parameter x`); a match binder inside a
  lambda shadows the lambda's parameter within its arm, as binders shadow
  function parameters today.
- `_` as a lambda parameter discards its argument: it binds nothing, any
  number of `_` parameters may appear, and it may carry an annotation
  (`fn(_: Int, _) => 0`). It is unrelated to placeholder application.
- A lambda annotation's lowercase names are the enclosing function's
  signature variables (rigid); any other lowercase name is E_UNBOUND
  `Unbound type variable b`. Lambdas are monomorphic: there is no
  generalization of a lambda's type.
- Calling a local with one or more arguments is no longer
  E_NOT_CALLABLE: it is an application, checked by types (section 3).
  `x()` keeps E_NOT_CALLABLE (section 4).

## 3. Types and checking

`Domain.Type.Ty` gains a binary, curried arrow `TFun (Ty v) (Ty v)`. A
function declared `fn f(p1: T1, …, pn: Tn): R` has scheme
`∀vs. T1 -> … -> Tn -> R`; a constructor `C(F1, …, Fn)` of `T(vs)` has
`∀vs. F1 -> … -> Fn -> T(vs)`. Unification, the occurs check, rigid and
flexible variables, holes and the inferred-type depth bound (with the
section 1 measure) extend to `TFun`. Inference stays per function with
explicit state (P001).

- Lambda: each parameter gets its annotation (rigid variables allowed) or
  a fresh meta; the body is inferred with the named parameters in scope;
  `fn(x, y) => e` has type `X -> Y -> E` and means `fn(x) => fn(y) => e`
  (section 5). A meta left unbound becomes a hole as in P001
  (`fn(x) => 1` used nowhere: `_ -> Int`).
- Application `e(a1, …, aj)`, `j ≥ 1`, is `e(a1)…(aj)`: for each argument
  unify the current type with `α -> β` (fresh metas), check the argument
  against `α`, continue with `β`. A current type that is Int, Bool, a
  declared type or a rigid variable is E_TYPE `Expected a function,
  found Int` at the first argument that does not fit (for a named callee
  see section 4).
- `a |> e` is checked as the application of section 5.
- Comparison: a type containing `->`, directly or through the fields of
  a declared type it applies (`Box(Int)` with `type Box(a) = Box(a ->
  a)`), is not comparable: E_TYPE `Type Int -> Int is not comparable`
  (and `Type Box(Int) is not comparable`). The check runs on the
  substituted operand type after groundness (P001 order kept: rigid, then
  hole, then function).
- Patterns: on a scrutinee of function type only `_` and binders fit; any
  other pattern is E_TYPE (`Expected Int -> Int, found Int`, as for a
  literal against a declared type today).
- Coverage and inhabitedness: every function type is inhabited (a
  diverging function exists at every type), so a constructor with a
  function field is inhabited iff its other fields are.
- Entry: `main`'s result must be printable, so must not contain `->`
  directly or through declared types' fields: E_ENTRY `Expected fn main()
  with a printable result type`. `main` is still parameterless.
- Type names in messages render curried with right-associative arrows,
  parenthesizing a function argument: `(Int -> Int) -> List(Int) ->
  List(Int)`; holes stay `_`.
- Long arrow spines: unification, substitution, the occurs check, depth
  measurement, rendering, specialization keys and Go type emission walk
  an arrow's result side iteratively (as a parameter array and a final
  result), so a 5,000-parameter declaration costs no recursion depth
  proportional to its parameter count (section 8, scale).

## 4. Named callees: arity is part of the declaration

A named function's declared parameter count `n` (a constructor's field
count) is its stage boundary: its body runs when its `n`th argument is
applied, and not before. For `f(a1, …, aj)`:

- `j = n`: a call (today's semantics and Go).
- `0 < j < n`: partial application. `a1 … aj` are evaluated now, left to
  right; the result is a function value awaiting argument `j + 1`.
- `j > n`: over-application: `f(a1…an)` runs the body and its result is
  applied to the rest. If the instantiated result type is Int, Bool, a
  declared type or a rigid variable, this is E_ARITY `Wrong number of
  arguments` at the call, today's over-application text unchanged.
- `n = 0`: only `f()`; `f()(x)` applies its result.
- Empty calls keep today's errors: `f()` on a function with parameters is
  E_ARITY `Wrong number of arguments`, `x()` on a local is E_NOT_CALLABLE
  `Local is not callable: x`, and `N()` on a nullary constructor stays
  E_NOT_CALLABLE. Application needs at least one argument.

The boundary is a property of the declaration, not of the type, and it
survives every use as a value. Two functions with the same type
`Int -> Int -> Int` can differ in timing:

```
fn add(x: Int, y: Int): Int = x + y;           -- body after 2 arguments
fn stuck(n: Int): Int -> Int = stuck(n);        -- body after 1 argument
fn drop1(f: Int -> Int): Int = 0;
fn use(f: Int -> Int -> Int): Int = drop1(f(1));
```

`use(add)` returns 0; `use(stuck)` diverges, because `f(1)` saturates
`stuck`. No representation may erase this difference (section 7).

Under-application is no longer E_ARITY: `take(3)` is a value of type
`List(a) -> List(a)`. Its misuse gets a hint under these provenance
rules:

- The hint is attached only to an E_TYPE that checking reports anyway; it
  never changes that diagnostic's code, span, or expected and found
  types, and it is computed from the checked expression after the failure,
  without further unification.
- It fires only when the expression whose type was found is, through
  parentheses only, a direct partial application `f(a1…aj)` with
  `0 < j < n` of a named function or constructor `f`, and the expected
  type at the failure is not a function type or a meta.
- It names that `f` and `n - j`: `Expected Int, found List(Int) ->
  List(Int); missing 1 argument to take?`. A partial application
  reached through a local, a lambda, a pipe or another call gets no hint.

## 5. Evaluation

Strict, left to right (ADR 001). Every application is staged:
`e(a1, …, aj)` means `e(a1)(a2)…(aj)`, and each single application of a
function value to one argument runs that value's body exactly when it
completes a stage boundary.

- Evaluation order of `e(a1, …, aj)`: `e`, then `a1`, then apply, then
  `a2`, then apply, and so on. Before a boundary, applying only records
  the argument, so for a saturated call `f(a1…an)` this is the familiar
  "all arguments left to right, then the body".
- Stage boundaries: a named function or constructor at its declared
  arity (section 4); a lambda at its last parameter (`fn(x, y) => e`
  runs `e` when `y` is applied, `fn(x) => fn(y) => e` likewise, and a
  lambda whose body returns a function runs that body on its last
  parameter, without waiting for more).
- Partial application `f(a1…aj)` evaluates `a1…aj` immediately; nothing
  is re-evaluated when the value is later applied (strict, once).
- Over-application `f(a, b, c)` with `f` of arity 2 is `f(a, b)(c)`:
  `a`, `b`, the body of `f`, then `c`, then the application.
- A lambda evaluates to a closure; nothing in its body runs until its
  last parameter is applied. Closures capture the values of the locals
  they read; every local is immutable, so capture by value and by
  reference agree.
- Pipe: `a |> e` evaluates the left operand `a` to a value `v` first,
  then evaluates the right side and applies. If `e` is `g(b1…bk)`, it is
  `g`, `b1…bk` and `v` applied in that order, with the stage boundaries
  of `g(b1…bk, v)`: `xs |> take(3)` evaluates `xs`, then `3`, then runs
  `take`'s body. Otherwise `e` is evaluated and applied to `v`. Divergence
  makes this order observable today; FX001 inherits it.

## 6. The instantiation rule and specialization

- Every reference to a named function or constructor, called or used as
  a value, carries its instantiation in the checked IR, wherever it
  occurs: function bodies, match arms, and lambda bodies at any depth.
  Value references are edges of the call graph exactly as calls are, so
  section 4 of the P001 spec applies unchanged: a reference inside a
  component must instantiate with bare caller variables or ground types.
  Applying a local function value creates no edge and no specialization.
- In the type-reference graph `->` is a type constructor like any other:
  `type T(a) = C(a -> T(List(a)));` is E_SPECIALIZATION.
- The proof of finiteness (P001 §4.2) needs no change: specialization
  keys are still (named declaration, ground argument vector), lambdas
  have no type parameters of their own, and an applied function value is
  already specialized where it was created. Lambda bodies are checked
  inside their enclosing function, so their references belong to that
  function's node in the graph.
- The hole representative stays valid: condition 4 of ADR 007 (no
  operation depends on a type argument) still holds, because lowering of
  closures, staged wrappers and application is uniform in the argument
  and result types.

## 7. IR and Go representation

Checked IR (Domain.Checked.Internal) gains:

- `FunctionRef FunctionId Instantiation` and `CtorRef CtorId
  Instantiation` for bare references;
- `Call` and `Construct` accept 1 to n arguments (partial when fewer);
- `Apply Expr (Array Expr)` for application of a non-named callee and for
  over-application's surplus;
- `Lambda (Array Param) Expr`, a `Param` being a typed local or a typed
  discard;
- `Pipe Expr Expr`, kept distinct so lowering can order the left operand
  first (section 5).

The monomorphic IR (Domain.IR.Internal) mirrors these, and its `Ty` gains
`TFun Ty Ty`, nested exactly as in the source type. A function value of
type `A -> B -> C` is a one-argument Go function returning a one-argument
Go function: `func(A) func(B) C`. Each stage boundary is therefore an
ordinary Go call boundary, and timing is preserved by construction; no
runtime arity check exists or is needed.

Go types. Each distinct ground function type in a program gets one named
Go type, emitted with the data types, so the text of long arrow spines
stays linear: `type bumpusFun1 func(int32) int32`, `type bumpusFun2
func(int32) bumpusFun1`. Function literals are written with the named
result type and are assignable to the named type.

Lowering, with `F` a named function of declared arity `n`. The nested
closures of the wrapper and lambda rows are superseded by Amendment A1
(section 13): the same stages, as top-level functions over immutable
environments.

| Source | Go |
|---|---|
| `f(a1…an)` | `F(a1, …, an)` (unchanged) |
| bare `f`, `n = 1` | `F` (already `func(A) R`) |
| bare `f`, `n > 1` | `FValue`, a generated staged wrapper (below) |
| partial `f(a1…aj)` | `FValue(a1)(a2)…(aj)` |
| over-application `f(a1…an, b…)` | `F(a1, …, an)(b1)…` |
| value `h` applied to `a1…aj` | `h(a1)(a2)…(aj)` |
| lambda `fn(x, y) => e` | `func(x X) bumpusFunN { return func(y Y) R { return e } }` |
| `a \|> e` | `func() R { v := a; return <e applied to v> }()` |
| `CtorRef` | the constructor function or its staged wrapper |

- The staged wrapper of `F`, generated once per specialization of a
  function used as a value, is nested closures that collect the
  arguments and call `F` at the last stage:
  `func FValue(p1 A) bumpusFun7 { return func(p2 B) R { return F(p1,
  p2) } }`. A declaration whose result is a function needs nothing extra:
  `F`'s Go result type is already the nested function type.
- Go evaluates `h(a1)(a2)` by calling `h(a1)` before any call inside
  `a2` (calls run in lexical order; locals and literals have no
  effects), which is section 5's order. Partial application is strict
  because Go evaluates call arguments before the call.
- The pipe's temporary is omitted when the left operand is a literal or
  a local, whose evaluation has no effect and cannot diverge.
- Cost: applying a function value to `k` arguments allocates up to
  `k - 1` intermediate closures. Direct named calls are unaffected. A
  saturation optimization is deferred until measured (non-goal).
- Lambda bodies lower as expressions, so a match inside one is lifted as
  today; Format.Go.Capture removes a lambda's named parameters from its
  body's free set, so a lifted match takes the lambda parameters it reads
  as ordinary parameters. A discarded parameter lowers to Go `_`.
- Comparison and printing helpers are generated by usage (Format.Go.Usage)
  and section 3 forbids both at function types, so no helper ever meets a
  Go `func` field. A declared type with a function field lowers it as the
  named Go function type, without the pointer used for recursive fields
  (a Go func value is already a reference).
- `scripts/structure.mjs` and the IR allowlists are unchanged; new nodes
  stay behind the existing internal modules.

## 8. Testing and proofs

Every rejection row asserts exact code, span and text.

- Syntax: arrow precedence and associativity; `(A, B) -> C` and
  `A -> B -> C` resolve to the same type; each E_SYNTAX form of section
  1; the nesting measure (a long spine is one level, a nested parameter
  is not); lambda, `_` parameter and `|>` precedence; postfix
  application chains; `->` and `|>` lexing next to negative literals and
  `|`.
- Names: each row of the section 2 table; lambda shadowing of a function
  and of a parameter; duplicate named lambda parameters; repeated `_`
  accepted; an unbound and a rigid type variable in a lambda annotation.
- Typing: partial, saturated and over-application of functions,
  constructors and locals; application of a non-function; occurs check
  through an arrow (`fn(f) => f(f)` is E_TYPE `Infinite type`);
  comparison of a function and of a type with a function field; patterns
  on a function scrutinee; non-printable `main`.
- Hint provenance: the hint on a direct partial application of a
  function and of a constructor, inside parentheses; no hint through a
  local, a lambda, a pipe or another call; no hint when the expected type
  is a function or a meta; with and without the hint the diagnostic's
  code, span and expected/found text are equal.
- Unifier properties (test/unify.test.mjs and its independent oracle)
  extended to generated types containing arrows.
- Specialization: distinct instantiations of a generic function used as
  a value (`map(id, …)` at Int and Bool); a value reference creating
  polymorphic recursion is E_SPECIALIZATION, including one inside a
  lambda inside a match arm; the finite-component generator gains
  value-reference edges, some inside lambdas; the representative-
  independence property gains lambdas with unused parameters.
- Execution: closures capturing parameters and match binders; returning
  closures; partial application evaluating its arguments once;
  over-application; constructor values and partial constructors
  (`map(Just, xs)`, `Cons(1)`); a lifted match inside a lambda reading
  the lambda's parameter; `|>` chains; the `add`/`stuck` pair of
  section 4 as non-divergent outcomes where possible.
- Timing probes, bounded: a test post-processes the emitted Go of a
  probe program so that entering a chosen function panics with a
  distinctive message (`bumpus-probe: <name>`), builds and runs it, and
  asserts that message. No probe exhausts Go's stack. Probes:
  `use(stuck)` with `stuck` a named function value (healthy: panics in
  `stuck`); the same with `fn(x) => stuck(x)` passed as a lambda;
  partial application strictness (`ignore(k3(probe(1)))` panics in
  `probe`); pipe order (`probe1(1) |> g(probe2(2))` panics in `probe1`).
- Oracle: the reference interpreter (test/) gains closures, staged
  application with declared arity, and `|>` with left-first order; the
  generated-program oracle gains higher-order functions, lambdas, partial
  and over-application, run in Go and compared.
- Identity: existing programs specialize and emit byte-identically
  (bootstrap snapshots unchanged); a new example examples/functions.bumpus
  with snapshot bootstrap/functions.go.
- Regression rows (scripts/regression.mjs), each with a probe that passes
  healthy and fails on its mutant, each probe being one of the bounded
  timing probes above where timing is the defect: `stage-value` (a named
  function value is lowered uncurried with an eta adapter, so
  `use(stuck)` returns instead of reaching `stuck`); `stage-lambda` (a
  lambda is eta-expanded to the arity of its type); `partial-strict`
  (partial application defers its arguments into the closure);
  `pipe-order` (the pipe is rewritten into the call, evaluating its left
  operand last); `lambda-capture` (Capture keeps a lambda parameter
  free, so a lifted match reads a missing local and Go compilation
  fails); `fun-compare` (comparison ignores arrows).
- Scale, with time bounds in large-source: a declaration with 5,000
  parameters called directly, used as a value and partially applied
  (checking, specialization, Go emission and `go build`); a chain of
  1,000 partial applications; a source arrow type of 1,000 parameters
  (one nesting level). The plan must also confirm that `go build`
  accepts a staged wrapper 5,000 closures deep, or bound the parameter
  count with a diagnostic if it does not.

## 9. Diagnostics that change deliberately

- Bare function name: E_UNBOUND becomes a function value (no diagnostic);
  bare zero-parameter function becomes E_ARITY `Expected f()`.
- Bare constructor with fields: E_ARITY becomes a function value.
- Calling a local or a binder with arguments: E_NOT_CALLABLE becomes
  application, E_TYPE `Expected a function, found T` when its type is not
  a function. With no arguments it stays E_NOT_CALLABLE.
- Unchanged by decision (user, 2026-10-08): over-application past a
  non-function result and `f()` on a function with parameters keep
  E_ARITY `Wrong number of arguments`.
- Under-application of a function or constructor: E_ARITY becomes a
  function value, typically E_TYPE where it is used, with the hint under
  section 4's provenance rules.
- Comparability: "every ground type is comparable" becomes "every ground
  type without a function in it".

test/diagnostics.test.mjs and the adt rows that pin the old behavior are
updated in the same change, each with the new expected code, span and
text.

## 10. Decisions

1. Curried semantics, Algol-like multi-argument syntax; `(A, B) -> C` is
   `A -> B -> C` (user, 2026-10-08).
2. Lambdas `fn(x) => e`, annotations optional, monomorphic; `_`
   discards (user).
3. `|>` in FN001, looser than comparison, left-associative, left operand
   evaluated first (user).
4. No local binding form in FN001 (user).
5. Declared arity is a stage boundary that survives use as a value; no
   function or lambda is ever eta-expanded (user review).
6. Nested Go function values, `func(A) func(B) C`, with staged wrappers
   for named functions and constructors used as values; direct saturated
   calls keep today's n-ary Go (user review).
7. Functions are neither comparable nor printable; function types are
   inhabited.
8. Constructors are curried functions with the same staging (user).
9. The under-application hint is narrow and provenance-based (user).
10. Arrow spines do not count as nesting depth and are traversed
    iteratively.

## 11. Open questions

None blocking. The `go build` depth question of section 8 was measured
while writing the plan; see Amendment A1 (section 13).

## 12. Review resolutions (2026-10-08)

| Finding | Resolution |
|---|---|
| Canonical uncurried representation loses timing (`use(stuck)` returns 0 instead of diverging) | Section 7 replaced: nested `func(A) func(B) C` values; staged wrappers; declared arity is a stage boundary (section 4 example). |
| Lambda eta-expansion delays the body; "delays nothing observable" was wrong | Lambdas are staged at their own last parameter and never eta-expanded (sections 5, 7); claim removed. |
| Q1 constructor values | Included, same staging (decision 8). |
| Q2 pipe order | Left operand first, then callee, then explicit arguments, keeping `g(b…, v)`'s boundaries (section 5); `Pipe` stays distinct in the IR; regression row `pipe-order`. |
| Q3 `_` lambda parameter | Discards, no binding, repeatable, separate from placeholder application (sections 1, 2). |
| Q4 hint | Narrow, with explicit provenance rules; never changes the underlying diagnostic (section 4); tests in section 8. |
| Divergence tests exhausted the stack | Bounded timing probes via instrumented emitted Go, named-value and lambda cases (section 8). |
| Generated depth of long declarations | Spine-flat nesting measure, iterative spine traversal, named Go function types for linear text, 5,000-parameter scale tests (sections 1, 3, 7, 8). |
| References in lambda bodies | Stated: every reference at any depth is a graph edge of the enclosing function (section 6); tests include one inside a lambda inside an arm. |

## 13. Amendment A1: linear staged lowering (2026-10-08)

Measured with Go 1.26.4 on hand-written Go of section 7's shape (a
named function of `n` Int parameters, its staged wrapper as nested
closures, named function types, called through all `n` stages):
`go build` took 1.3 s at n = 50, 2.6 s at 100, 13.9 s at 200 and 221 s
at 300; at 1,000 it had not finished after 10 minutes. Each nested
closure captures every outer parameter, so the compiler's work grows far
faster than the text. test/large-source.test.mjs already checks a
20,000-parameter declaration, so a parameter bound would have to apply
only to value use, an arbitrary rule. Rejected.

Replacement, keeping section 7's types and every rule of sections 4-5:
no Go closure literal is nested inside another. Each staged value is a
chain of top-level Go stage functions, each returning one closure that
captures a single environment value:

- A staged wrapper of `F` (arity `n ≥ 2`) has `n - 1` stage functions;
  stage `k` receives the environment of arguments `1…k-1` and returns
  the closure taking argument `k`, which extends the environment and
  calls stage `k + 1`, or `F` with every argument at the last stage.
- Every lambda is lifted the way matches are (E005): a top-level stage
  chain whose initial environment holds the lambda's free locals
  (Format.Go.Capture) and whose last stage binds the free locals and
  parameters the body reads, then evaluates the body. A one-parameter
  lambda is a one-stage chain. Nested lambdas are separate chains.
- Environments are immutable once built (a stage builds a new one), so
  a shared partial application is never disturbed by a later
  application.

Same hand-written measurement with an environment struct copied per
stage: 1.1 s at n = 300, 1.1 s at 1,000, 12.8 s at 5,000. Copying the
whole struct costs O(n) per stage, O(n²) per full application, which
the linear-cost requirement excludes; it is not a fallback. The plan
uses a linked environment (each stage allocates one node holding its
argument and a pointer to the previous node; the last stage reads the
chain once), O(1) per stage and O(n) text, and measures it as its first
task before any lowering code is written. If it fails that measurement,
the representation is reconsidered with the user.

Status: architecture approved by the user 2026-10-08 (top-level stages,
immutable environments); the linked representation awaits Task 1's
measurement.

### A1 measurement (plan Task 1, 2026-10-08; not adopted)

scripts/stage-probe.mjs and scripts/stage-shapes.mjs, Go 1.26.4, raw logs
.build/fn001-task1/run{1,2,3}-*.log. Build seconds at n = 5,000 and
20,000 and the growth exponent k (t(20,000)/t(5,000) = 4^k; 1 linear, 2
quadratic, the plan's bound 1.25):

| Program | 5,000 | 20,000 | k |
|---|---|---|---|
| floor: n function types and `f` only | 0.53 | 4.33 | 1.52 |
| direct calls of `f`, no staged value | 0.60 | 5.05 | 1.54 |
| linked chain, value never applied | 2.65 | 29.7 | 1.74 |
| linked, one node type per stage replaced by one shared type | 4.20 | 61.5 | 1.93 |
| packed: shared node type, last stage passes the chain to `F` | 1.67 | 9.17 | 1.23 |
| linked, applied by 20,000 statements | 11.2 | 161 | 1.92 |
| linked, applied by one chained expression | 18.0 | >300 (timeout) | ≥2.1 |
| packed, applied by one chained expression | 16.8 | 287 | 2.05 |

Run time per full application is linear for every chain shape (linked
k = 1.10). Findings: (1) the linked environment as specified fails the
build bound; its last stage, which unpacks `n` locals and makes an
`n`-argument call, is the superlinear part: removing it (`packed`) brings
the staged value's own cost above the floor to k ≈ 1.04 (1.14 s to
4.84 s). (2) Applying a value to `n` arguments inside one Go function is
superlinear for `go build` whatever the representation (k ≈ 2), as
statements or as one expression. (3) The floor itself is k ≈ 1.5: `n`
named function types plus an `n`-parameter function; not yet split.
Per the user's ruling no shape is adopted; the representation is to be
reconsidered with the user.

### A1 measurement, round 2 (2026-10-08; candidates, nothing adopted)

Authorized by the user as measurement only. Raw logs
.build/fn001-task1/run4-*.log. Total `go build` seconds (the acceptance
evidence; differences are attribution only):

| Program | 5,000 | 20,000 | k |
|---|---|---|---|
| function types alone | 0.28 | 0.66 | 0.62 |
| `f`'s signature, body `return p0` | 0.17 | 0.22 | 0.19 |
| `f` with the checksum body (one 20,000-element literal and a loop) | 0.46 | 5.25 | 1.76 |
| that `f` and a direct call | 0.45 | 5.23 | 1.77 |
| today's n-ary convention, mixed body (each parameter read twice) | 1.51 | 33.6 | 2.24 |
| packed, per-type arrays, mixed body, value built only | 2.49 | 18.2 | 1.43 |
| packed, per-type arrays, mixed body, applied in blocks of 64 | 2.45 | 19.2 | 1.48 |
| packed, struct per parameter, mixed body, built only | 2.69 | 24.6 | 1.60 |
| packed, struct per parameter, mixed body, blocks of 64 | 2.90 | 26.9 | 1.61 |
| packed, Int body, blocks of 16 | 2.23 | 16.3 | 1.44 |
| packed, Int body, blocks of 64 | 2.08 | 13.1 | 1.33 |
| packed, Int body, blocks of 256 | 2.21 | 13.1 | 1.28 |

Run time per full application is linear for every staged program
(k = 1.05-1.13). Evaluation order, body entry at a declared-arity
boundary, and reuse of a shared partial application across block
boundaries match the semantics in four cases (boundaries inside a block,
on block edges, in the first block; n = 7 to 300); a mutant whose helpers
evaluate their block's arguments first fails the check.

Findings. (1) The signature and the function types are linear; the
superlinear Go cost is in large function bodies and expressions, and
today's n-ary convention already pays it (k = 2.24 for an ordinary mixed
body), so no representation makes `go build` linear at these sizes. (2)
The packed convention with per-type arrays builds an ordinary body
faster than today's n-ary function (18.2 s against 33.6 s at 20,000);
the struct-per-parameter variant is slower than arrays. (3) Block
splitting removes the quadratic application chain (287 s or a timeout
before; 13.1-19.2 s now); blocks of 64 and 256 are equivalent, 16 is
slower. (4) Not measured: how a function used both directly and as a
value shares one body between the n-ary entry and the packed one.
