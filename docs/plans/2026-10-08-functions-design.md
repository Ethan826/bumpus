# First-class functions, lambdas and closures: design (FN001)

Status: direction settled with the user 2026-10-08 (curried semantics with
Algol-like multi-argument syntax; lambdas `fn(x) => body`; `|>` in scope;
no local binding form). This document is a draft awaiting the user's
review. Nothing is implemented; no plan exists yet.

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
lambda or function parameter; placeholder holes such as `take(_, xs)`;
default, variadic, overloaded-by-arity or named parameters; `>>`/`<<`
(Prelude functions once a Prelude exists, C001); rank-2 or polymorphic
lambdas and polymorphic fields; foreign Go functions (I001); comparing or
printing functions.

Preserved: phase boundaries and both IR allowlists; strict evaluation; the
structural order and print format of ADR 005; every existing diagnostic
not listed in section 9. A program that uses no function type, lambda,
function value, partial application or `|>` emits byte-identical Go
(bootstrap/*.go unchanged).

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
lparam      = lower, [ ":", type ] ;
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
- Each `->` is one type nesting level for E_NESTING (ADR 006), as each
  type argument is.
- A lambda, like `if` and `match`, extends as far right as possible and
  must be parenthesized as an operand: `f(fn(x) => x)` needs none (an
  argument is an expression), `(fn(x) => x)(1)` does.
- `|>` binds looser than comparison and is left-associative:
  `xs |> take(3) |> length` is `(xs |> take(3)) |> length`. Neither
  operand may be an unparenthesized `if`, `match` or lambda.
- Application is postfix and repeatable on any primary: `f(1)(2)`,
  `(g)(x)`, `make()(x)`. `f()` with no arguments is allowed only on a
  named zero-parameter function (section 3).
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
  the same name in the lambda body. Lambda parameters must be distinct
  (E_DUPLICATE `Duplicate parameter x`); a match binder inside a lambda
  shadows the lambda's parameter within its arm, as binders shadow
  function parameters today.
- A lambda annotation's lowercase names are the enclosing function's
  signature variables (rigid); any other lowercase name is E_UNBOUND
  `Unbound type variable b`. Lambdas are monomorphic: there is no
  generalization of a lambda's type.
- Calling a local is no longer E_NOT_CALLABLE: it is an application,
  checked by types (section 3).

## 3. Types and checking

`Domain.Type.Ty` gains a binary, curried arrow `TFun (Ty v) (Ty v)`. A
function declared `fn f(p1: T1, …, pn: Tn): R` has scheme
`∀vs. T1 -> … -> Tn -> R`; a constructor `C(F1, …, Fn)` of `T(vs)` has
`∀vs. F1 -> … -> Fn -> T(vs)`. Unification, the occurs check, rigid and
flexible variables, the depth bound and holes extend structurally to
`TFun`. Inference stays per function with explicit state (P001).

- Lambda: each parameter gets its annotation (rigid variables allowed) or
  a fresh meta; the body is inferred with those locals in scope; the
  lambda's type is the curried arrow. A meta left unbound becomes a hole
  as in P001 (`fn(x) => 1` used nowhere: `_ -> Int`).
- Application `e(a1, …, aj)`, `j ≥ 1`, applies one argument at a time:
  infer `e`, then for each argument unify the current type with
  `α -> β` (fresh metas), check the argument against `α`, continue with
  `β`. A current type that is Int, Bool, a declared type or a rigid
  variable is E_TYPE `Expected a function, found Int` at the first
  argument that does not fit (for a named callee see section 4).
- `a |> e` is checked as `e(a)` after the rewrite of section 5.
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

## 4. Named callees: arity is part of the declaration

A named function's declared parameter count `n` (a constructor's field
count) decides when its body runs. For `f(a1, …, aj)`:

- `j = n`: a call (today's semantics and Go).
- `0 < j < n`: partial application. `a1 … aj` are evaluated now, left to
  right; the result is a function of the remaining `n - j` arguments;
  the body runs when it is saturated.
- `j > n`: over-application: call with the first `n` and apply the result
  to the rest, one application per the rule of section 3. If the
  instantiated result type is Int, Bool, a declared type or a rigid
  variable, this is E_ARITY `Expected n argument(s)` at the call, as
  today's over-application.
- `n = 0`: only `f()`; `f(x)` is over-application of its result.
- Under-application is no longer E_ARITY: `take(3)` is a value of type
  `List(a) -> List(a)`. When such a partial application of a named
  function or constructor meets a non-function expected type, the
  E_TYPE message gains a hint: `Expected Int, found List(Int) ->
  List(Int); missing 1 argument to take?` (section 9 lists the rows that
  change).

A function whose declared result is itself a function (`fn adder(n: Int):
Int -> Int = fn(x) => x + n;`) has arity 1: `adder(1)` runs the body and
returns the lambda; `adder(1, 2)` is over-application. Its scheme is
`Int -> Int -> Int`, the same type as a two-parameter function's; only
evaluation timing differs, and with no effects and only divergence
observable that difference is visible only as which call fails to
terminate. FX001 inherits this rule (effects run when the declared arity
is reached).

## 5. Evaluation

Strict, left to right (ADR 001), with these additions:

- An application `e(a1, …, aj)` evaluates `e`, then `a1 … aj` left to
  right, then applies. With a named callee there is no `e` to evaluate.
- Over-application `f(a1, …, aj)` with `j > n` evaluates `a1 … an`,
  calls `f`, then evaluates the remaining arguments and applies:
  `f(a, b)(c)` and `f(a, b, c)` mean the same.
- A lambda evaluates to a closure; nothing in its body runs until it is
  applied. Closures capture the values of the locals they read; every
  local is immutable, so capture by value and by reference agree.
- `a |> e` is syntax: when `e` is a call or application `g(b1, …, bk)`,
  it is `g(b1, …, bk, a)`; otherwise it is `e(a)`. So `xs |> take(3)` is
  `take(3, xs)` and evaluates `3` before `xs`. This is unobservable
  today; FX001 must revisit it before effects can be ordered by a pipe.

## 6. The instantiation rule and specialization

- Every reference to a named function or constructor, called or used as
  a value, carries its instantiation in the checked IR. Value references
  are edges of the call graph exactly as calls are, so section 4 of the
  P001 spec applies unchanged: a value reference inside a component must
  instantiate with bare caller variables or ground types. Applying a
  local function value creates no edge and no specialization.
- In the type-reference graph `->` is a type constructor like any other:
  `type T(a) = C(a -> T(List(a)));` is E_SPECIALIZATION.
- The proof of finiteness (P001 §4.2) needs no change: specialization
  keys are still (named declaration, ground argument vector), lambdas
  have no type parameters of their own, and an applied function value is
  already specialized where it was created.
- The hole representative stays valid: condition 4 of ADR 007 (no
  operation depends on a type argument) still holds, because lowering of
  closures, adapters and application is uniform in the argument and
  result types.

## 7. IR and Go representation

Checked IR (Domain.Checked.Internal) gains:

- `FunctionRef FunctionId Instantiation` and `CtorRef CtorId
  Instantiation` for bare references;
- `Call` and `Construct` accept 1 to n arguments (partial when fewer);
- `Apply Expr (Array Expr)` for application of a non-named callee and for
  over-application's surplus;
- `Lambda (Array { id ∷ LocalId, ty ∷ Ty Open }) Expr`.

The monomorphic IR (Domain.IR.Internal) mirrors these, and its `Ty` gains
`TFun (Array Ty) Ty`, the canonical uncurried form: Specialize flattens
every arrow chain, so a ground `A -> B -> C` is `TFun [A, B] C` and its
result is never a `TFun`. There is one Go representation per type:
`func(A, B) C`. No runtime arity check exists or is needed.

Lowering, with `F` a named function of declared arity `n` whose
canonical value type has `k ≥ n` parameters:

| Source | Go |
|---|---|
| `f(a1…an)` | `F(a1, …, an)` (unchanged) |
| bare `f`, `k = n` | `F` |
| bare `f`, `k > n` | adapter `func(p1…pk) R { return F(p1…pn)(pn+1…pk) }` |
| partial `f(a1…aj)` | IIFE binding `a1…aj` to temps, returning a closure over the rest |
| over-application | `F(a1…an)` then the canonical application of the rest |
| value `h` of `TFun [T1…Tk] R` applied to `j` | `j = k`: `h(…)`; `j < k`: IIFE closure; `j > k`: apply `k`, then the rest |
| lambda `fn(x, y) => e` of canonical `TFun [X, Y, Z] R` | `func(x X, y Y, z Z) R { return (e)(z) }` (eta-expanded to the canonical arity) |
| `CtorRef` | the existing constructor function, or an adapter as above |

- Partial application's IIFE gives the strictness of section 5 (Go
  would otherwise defer argument evaluation into the closure).
- Eta-expanding a lambda body that returns a function delays nothing
  observable: a lambda's body runs only when the lambda is applied, so
  binding the extra canonical parameters cannot run any effect earlier.
  A named function is never eta-expanded (section 4).
- Lambda bodies lower as expressions, so a match inside one is lifted as
  today; Format.Go.Capture removes a lambda's parameters from its body's
  free set, so a lifted match takes the lambda's parameters it reads as
  ordinary parameters.
- Comparison and printing helpers are generated by usage (Format.Go.Usage)
  and section 3 forbids both at function types, so no helper ever meets a
  Go `func` field. A declared type with a function field lowers its field
  as the Go `func` type, without the pointer used for recursive fields
  (a Go func value is already a reference).
- `scripts/structure.mjs` and the IR allowlists are unchanged; new nodes
  stay behind the existing internal modules.

## 8. Testing and proofs

Every rejection row asserts exact code, span and text.

- Syntax: arrow precedence and associativity; `(A, B) -> C` and
  `A -> B -> C` resolve to the same type; each E_SYNTAX form of section
  1; lambda and `|>` precedence; postfix application chains; `->` and
  `|>` lexing next to negative literals and `|`.
- Names: each row of the section 2 table; lambda shadowing of a function
  and of a parameter; duplicate lambda parameters; an unbound type
  variable in a lambda annotation; a rigid one in a lambda annotation.
- Typing: partial, saturated and over-application of functions,
  constructors and locals; application of a non-function; occurs check
  through an arrow (`fn(f) => f(f)` is E_TYPE `Infinite type`);
  comparison of a function and of a type with a function field; patterns
  on a function scrutinee; non-printable `main`; the hint.
- Unifier properties (test/unify.test.mjs and its independent oracle)
  extended to generated types containing arrows.
- Specialization: distinct instantiations of a generic function used as
  a value (`map(id, …)` at Int and Bool); a value reference creating
  polymorphic recursion is E_SPECIALIZATION; the finite-component
  generator gains value-reference edges; the representative-independence
  property gains lambdas with unused parameters.
- Execution: closures capturing parameters and match binders; returning
  closures; partial application evaluating its arguments once
  (observable only as divergence: with `fn k3(a: Int, b: Int, c: Int):
  Int = a;` and `fn ignore(f: Int -> Int -> Int): Int = 0;`,
  `ignore(k3(loop()))` must not terminate); over-application;
  eta-adapters for `adder`; constructor values (`map(Just, xs)`); a
  lifted match inside a lambda reading the lambda's parameter; `|>` chains.
- Oracle: the reference interpreter (test/) gains closures, curried
  application and `|>`; the generated-program oracle gains higher-order
  functions, lambdas and partial application, run in Go and compared.
- Identity: existing programs specialize and emit byte-identically
  (bootstrap snapshots unchanged); a new example examples/functions.bumpus
  with snapshot bootstrap/functions.go.
- Regression rows (scripts/regression.mjs), each with a probe that passes
  healthy and fails on its mutant: `partial-strict` (partial application
  defers argument evaluation into the closure); `declared-arity` (a named
  function returning a function is eta-expanded, so with `fn stuck(n:
  Int): Int -> Int = loop(n);` and `fn drop1(f: Int -> Int): Int = 0;`,
  `drop1(stuck(1))` stops diverging); `lambda-capture` (Capture keeps a lambda
  parameter free, so the lifted match reads a stale or missing local and
  Go compilation fails); `fun-compare` (comparison groundness ignores
  arrows).
- Divergence probes need a bounded harness: Go reports unbounded
  recursion as a fatal stack overflow, so these tests assert that fatal
  exit within a time bound, against a mutant that prints. No existing
  test does this; the plan must cost it.
- Scale: large-source gains a chain of 1,000 partial applications and a
  1,000-parameter function used as a value, with time bounds.

## 9. Diagnostics that change deliberately

- Bare function name: E_UNBOUND becomes a function value (no diagnostic);
  bare zero-parameter function becomes E_ARITY `Expected f()`.
- Bare constructor with fields: E_ARITY becomes a function value.
- Calling a local or a binder: E_NOT_CALLABLE becomes application,
  E_TYPE `Expected a function, found T` when its type is not a function.
- Under-application of a function or constructor: E_ARITY becomes a
  function value, typically E_TYPE with the `missing N argument(s)` hint
  where it is used.
- Comparability: "every ground type is comparable" becomes "every ground
  type without a function in it".

test/diagnostics.test.mjs and the adt rows that pin the old behavior are
updated in the same change, each with the new expected code, span and
text.

## 10. Decisions

1. Curried semantics, Algol-like multi-argument syntax; `(A, B) -> C` is
   `A -> B -> C` (user, 2026-10-08).
2. Lambdas `fn(x) => e`, annotations optional, monomorphic (user).
3. `|>` in FN001, syntactic, looser than comparison, left-associative
   (user); `>>`/`<<` wait for a Prelude.
4. No local binding form in FN001 (user).
5. Declared arity decides when a named function's body runs; over- and
   partial application follow from it; named functions are never
   eta-expanded.
6. One canonical uncurried Go representation per ground function type,
   with adapters at value-use sites; no runtime arity checks.
7. Functions are neither comparable nor printable; function types are
   inhabited.
8. Constructors are curried functions like any other.

## 11. Open questions for review

1. Constructors as function values and partial constructors (decision
   8): included for uniformity (`map(Just, xs)`), or deferred?
2. Pipe evaluation order (section 5): the syntactic rewrite evaluates the
   left operand last. Accept now and let FX001 revisit, or evaluate the
   left operand first (costs a Go temporary per pipe stage)?
3. `_` as a lambda parameter (`fn(_) => 0`) is common and cheap; include,
   or leave with the deferred placeholder work?
4. The under-application hint fires only for a partial application of a
   named callee meeting a non-function expected type. Wider (any
   function-typed value whose final result would fit) needs a trial
   unification; worth it?
