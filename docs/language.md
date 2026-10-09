# Bumpus language specification (stage 0, closed ADTs, comparison, polymorphism, functions)

Provisional name. A file is one program: type declarations and functions in
any order, with required function signatures. Behavioral claims below name
their verifying test file in test/.

Identifiers: ASCII letters/underscore then letters/digits/underscore.
Whitespace: space, tab, CR, LF. Reserved words: `fn if then else true false
Int Bool type match`, and the lone `_`. `type`, `match` and `_` were
identifiers in Stage 0 (ADR 003). Punctuation includes `|`, `{`, `}`, the
single token `=>` (adt-syntax), the operators `== != < <= > >=`, and
(FN001) `->` and `|>`, matched longest first (`==` before `=>` and `=`,
`->` before an integer's minus, `|>` before `|`; fn-syntax); a lone `!` is
E_LEX (compare).
Comments and strings do not exist.

```ebnf
program     = { declaration } ;
declaration = typedecl | function ;
typedecl    = "type", upper, [ "(", lower, { ",", lower }, ")" ], "=",
              ctor, { "|", ctor }, ";" ;
ctor        = upper, [ "(", type, { ",", type }, ")" ] ;
function    = "fn", identifier, "(", [ parameters ], ")", ":", type,
              "=", expression, ";" ;
parameters  = parameter, { ",", parameter } ;
parameter   = identifier, ":", type ;
type        = arrow ;
arrow       = operand, [ "->", arrow ]
            | "(", type, ",", type, { ",", type }, ")", "->", arrow ;
operand     = "Int" | "Bool" | lower
            | upper, [ "(", type, { ",", type }, ")" ] | "(", type, ")" ;
expression  = "if", expression, "then", expression, "else", expression
            | "match", expression, "{", arm, { ",", arm }, [ "," ], "}"
            | "fn", "(", lparam, { ",", lparam }, ")", "=>", expression
            | pipeline ;
lparam      = ( lower | "_" ), [ ":", type ] ;
pipeline    = comparison, { "|>", comparison } ;
arm         = pattern, "=>", expression ;
pattern     = "_" | lower | upper, [ "(", pattern, { ",", pattern }, ")" ]
            | integer | "true" | "false" ;
comparison  = addition, [ ( "==" | "!=" | "<" | "<=" | ">" | ">=" ),
              addition ] ;
addition    = atom, { "+", atom } ;
atom        = primary, { "(", [ arguments ], ")" } ;
primary     = integer | "true" | "false" | identifier
            | "(", expression, ")" ;
arguments   = expression, { ",", expression } ;
integer     = [ "-" ], digit, { digit } ;
upper       = identifier starting with "A".."Z" ;
lower       = identifier starting with "a".."z" or "_", other than "_" ;
```

A constructor field list must be nonempty (`C()` is E_SYNTAX). Type and
constructor names must be `upper`; `Int` and `Bool` are reserved, so
`type Int = A;`, `type Bool = A;` and `type T = Int;` are E_SYNTAX. `match`
and `if` are expression forms at the same level, so either must be
parenthesized as an addition operand; an empty `match x {}` is E_SYNTAX; a
trailing comma is accepted (adt-match). Minus belongs only to integer literals
(may be separated by whitespace); leading zeroes are decimal; values must fit
int32 (E_INTEGER). Integer patterns use the same syntax.

Types (P001, ADR 007). A lowercase name in a type is a type variable; there
is no new reserved word, so `fn main(): int = 1;` declares a variable
`int`, not a misspelled `Int` (it is then E_ENTRY, below). `type T() =
A;` is E_SYNTAX `Expected a type parameter`, `List()` is E_SYNTAX
`Expected a type` at `)`, and `Int(a)` and `a(Int)` are E_SYNTAX at `(`.
Each type argument is one nesting level (ADR 006). An applied type spans
its head through its closing parenthesis (test/poly-syntax.test.mjs).

Function syntax (FN001; ADR 008; test/fn-syntax.test.mjs). `->` is
right-associative and binds loosest in types: `Int -> Int -> Int` is
`Int -> (Int -> Int)`; `(A, B) -> C` is exactly `A -> B -> C` and `(A) ->
B` is `A -> B`. A parenthesized list of two or more types not followed by
`->` is E_SYNTAX `Expected ->`; `() -> A` is E_SYNTAX `Expected a type` at
`)`. An arrow's parameter side is one nesting level deeper than the arrow,
its result side is not, so a spine of any length is one level
(fn-depth). A lambda `fn(x, _: Int) => e` extends as far right as
possible and needs parentheses as an operand (`(fn(x) => x)(1)`); an empty
or malformed parameter list is E_SYNTAX `Expected a parameter`. `|>` binds
looser than comparison and associates left (`xs |> take(3) |> length`);
neither operand may be an unparenthesized `if`, `match` or lambda.
Application is postfix and repeatable on any primary (`f(1)(2)`, `(g)(x)`,
`make()(x)`); a value application with an empty list (`f(1)()`) is
E_SYNTAX `Expected an expression` at `)`. A lambda spans `fn` through its
body, a pipeline its left through its right operand, an application its
callee through its closing parenthesis (`(add)(1)` from its `(`).

## Semantics

Types: `Int`, `Bool`, declared types (closed, recursive, mutually recursive
in any declaration order; adt-types), applied types such as `List(Int)` or
`Pair(a, List(b))`, type variables, and function types `A -> B`. No
coercions.
Addition needs Int operands. A comparison infers its left then right operand,
and the right must have the left's type, else E_TYPE at the right operand;
its result is Bool. Every ground type is comparable, including uninhabited
ones; a type containing a variable or a function is not (Polymorphism and
Functions, below). `if` needs a Bool condition and equal branch types.
Every function is checked, including unused ones and unreachable arms.

Names. Types, and functions plus constructors (one global table), are distinct
namespaces; locals are parameters, pattern binders and lambda parameters,
and shadow globals. A bare name is a local, else a nullary constructor (a
value), else a function or a constructor with fields, which is a function
value; a bare zero-parameter function is E_ARITY `Expected f()`. Called
with arguments, a function is a call, a constructor a construction, and a
local or binder an application, checked by types. With no arguments, `x()`
on a local and `N()` on a nullary constructor are E_NOT_CALLABLE, and
`f()` on a function with parameters is E_ARITY `Wrong number of
arguments` (fn-names, fn-check). A binder shadows a parameter within its
own arm only; outside it is E_UNBOUND. A lambda parameter shadows anything
of its name in the lambda body; named lambda parameters must be distinct
(E_DUPLICATE `Duplicate parameter x`); `_` binds nothing and may repeat.
A lambda annotation's lowercase names are the enclosing signature's
variables; any other is E_UNBOUND `Unbound type variable b` (fn-names).
Duplicate types, globals, parameters or binders
(`Pair(a, a)` is never equality) are E_DUPLICATE at the first duplicated
declaration in source order, whatever its kind (`fn A(): Int = 1; type T = A;`
reports the function). A missing `main` is E_ENTRY with message
`Expected fn main()`, and so is a `main` with parameters; `main` may return
any ground type without a function in it, else E_ENTRY `Expected fn main()
with a printable result type` (adt-print, fn-rules). Rejection fixtures: test/diagnostics.test.mjs,
adt-types, adt-match.

Patterns. `_` matches anything; a lowercase name binds; an uppercase name is a
constructor with exactly its field count (E_ARITY); literals match their
primitive type. Pattern type errors are E_TYPE at the pattern. All arm bodies
must have the first arm's type.

Coverage. After the whole program type-checks, each match is checked in
source pre-order, functions in declaration order. The first redundant arm is
E_REDUNDANT (at its pattern); then a non-exhaustive match is E_NON_EXHAUSTIVE
(at the whole match) with message `Missing pattern: <witness>`, rendered like
`Cons(_, Nil)`, `false`, `2`. Witnesses never name an uninhabited
constructor. A type with no inhabited constructor (`type T = C(T);`) is legal;
a wildcard over only such a remainder is E_REDUNDANT (adt-coverage;
coverage.test.mjs compares with a brute-force oracle).

Evaluation is strict, operands and arguments left to right; `if` and `match`
evaluate the scrutinee/condition and only the selected branch. Arms are tried
in order. Deep structures work: an 8192-element list built by doubling sums,
prints and compares correctly (adt-match, adt-print, adt-order). Int addition
wraps modulo 2^32.

Comparison. `==`, `!=`, `<`, `<=`, `>`, `>=` bind looser than `+` and do not
chain: `a < b < c` and `a == b == c` are E_SYNTAX `Comparisons do not chain`
at the second operator. `if` and `match` operands need parentheses. The span
of a comparison runs from its left to its right operand. Both operands are
evaluated, left then right, before comparing; there is no short circuit
(compare, adt-order). The order is one structural total order on well-formed
values: Int by signed int32; Bool `false < true`; a declared type by
constructor declaration position, then fields left to right, the first
difference deciding. `==` holds exactly when the order says equal (separately
built equal values are equal, never by identity); `!=` is its negation
(adt-order, whose independent interpreter oracle checks every operator, and
the `ctor-order` and `first-field` regression rows).

Printing. The executable prints `main`'s value plus LF; printing is a backend
wrapper, not a source effect. Int prints decimal with a leading `-` when
negative, Bool `true` or `false`, a declared value `Name` or
`Name(f1, f2)` with `, ` separators: the coverage-witness format without `_`,
so every printed value is valid Bumpus source that reproduces the value
under the same declarations (adt-print round trip). Re-reading is bounded by
the nesting limit below: a printed list `Cons(1, Cons(2, … Nil))` of more
than 128 elements nests deeper than 128 levels, so it is rejected with
E_NESTING rather than recompiled (heap-based phases, BACKLOG H001, would lift this). Malformed
values, possible only from foreign code (I001), panic with `bumpus: malformed
value` when a comparison or print visits a nil field pointer or unknown tag;
comparison stops at the first difference, so later malformed fields can go
unnoticed; total order is claimed only for well-formed values.
Foreign (Go) values are not validated: Proposed, with I001.

Polymorphism (P001; ADR 007; spec docs/plans/2026-10-08-polymorphism-design.md).

- Scoping. A type declaration's parameters scope over its own
  constructors; a field naming any other lowercase name is E_UNBOUND
  `Unbound type variable b`, and a repeated parameter is E_DUPLICATE
  `Duplicate type parameter a` at the repetition. Phantom parameters are
  allowed. A declared type used with the wrong number of arguments,
  including none where it has parameters (`List`), is E_ARITY `Wrong
  number of type arguments for List` at the reference. A function's type
  variables are every lowercase name in its signature, implicitly
  quantified over the whole signature; one may appear only in the result
  (`fn loop(): a = loop();`). `main` must have a result without type
  variables: otherwise E_ENTRY `Expected fn main() with a concrete result
  type` (poly-syntax).
- Rigid and flexible variables. Inside its own function a signature's
  variable is rigid: it equals only itself, so `fn f(x: a): Int = x;` is
  E_TYPE `Expected Int, found a`, and `fn g(x: a, y: b): a = y;` is E_TYPE.
  Constructors are polymorphic (`Nil : List(a)`). Each use of a function
  or constructor instantiates its variables afresh, so
  `pair(id(1), id(true))` is `Pair(Int, Bool)`. Unification never makes a
  type contain itself: in `match Nil { Cons(h, t) => same(h, t), Nil => 0 }`
  with `fn same(x: a, y: a): Int` it is E_TYPE `Infinite type: _ occurs
  in List(_)` at the argument `t`, whose unification fails. Messages name
  whole types, `_` for an undetermined part (`Expected Pair(Int, Int),
  found Pair(Int, Bool)`) (poly-check,
  unify; regression rows `occurs`, `rigid`, `instantiate`).
- Holes. A type argument nothing determines (the element type in
  `length(Nil)`) stays undetermined; there is no typing default.
  It does not change the program's meaning: compilation picks one fixed
  representative (Int) for such holes, which is valid because no
  comparison, `main` result or other operation depends on them
  (poly-run, poly-properties representative independence).
- Comparison groundness. A comparison's operand type, once the function is
  checked, must have no variable: a signature variable is E_TYPE `Type a
  is not comparable` (also `Type List(a) is not comparable`), and an
  undetermined one is E_TYPE `Ambiguous type List(_) in comparison`
  (`Nil == Nil`), both at the left operand; the first is reported first
  (poly-check). Comparing `List(Int)` values inside a generic function is
  fine (poly-run).
- Patterns and coverage. On a scrutinee whose type is a variable, only `_`
  and binders fit; a constructor or literal pattern is E_TYPE. Coverage
  treats variables and undetermined types as abstract and inhabited, and
  checks each source match once, whatever its instantiations; a
  constructor's field types are its declared ones with the arguments
  substituted, so for an uninhabited `Void`, `Maybe(Void)` needs no `Just`
  arm (poly-coverage).
- The instantiation rule. Within a group of mutually recursive functions
  (a strongly connected component of the call graph), every type argument
  of a call to a member of the group must be a bare variable of the
  calling function or contain no variable at all; likewise for type
  declarations that refer to each other through constructor fields. So
  `fn f(x: a): Int = f(Cons(x, Nil));` is E_SPECIALIZATION `Recursive call
  to f changes its type arguments` and `type Nest(a) = Nil | Cons(a,
  Nest(List(a)));` is E_SPECIALIZATION `Recursive use of Nest changes its
  type arguments`. The rule guarantees that only finitely many
  specializations exist (proof: spec §4.2); it also rejects some finite
  programs, such as `f(a)` calling `g(List(a))` with `g(b)` calling
  `f(Int)` (poly-termination).
- Inferred-type depth. Composing generic calls can infer types far deeper
  than any written one. A type deeper than 1,000 levels is E_NESTING
  `Inferred type nesting exceeds 1000 levels` at the expression whose type
  would exceed it, never a stack overflow (poly-depth; ADR 007).
- Specialization limit. Each distinct use of a generic function at ground
  type arguments, and each distinct ground application of a parameterized
  type, is one specialization; monomorphic declarations do not count. More
  than 10,000 in one program is E_SPECIALIZATION `More than 10000
  specializations` at the reference that would create the 10,001st (for
  one first created in a signature, the whole function declaration). A
  generic declaration never used is checked but not emitted (poly-run).
- Evaluation and printing are unchanged: a generic value prints with its
  source constructor names and re-reads (`Cons(Pair(1, true), Nil)`;
  poly-run, examples/lists.bumpus and bootstrap/lists.go).

Functions (FN001; ADR 008; spec docs/plans/2026-10-08-functions-design.md).

- Typing. `fn f(p1: T1, …, pn: Tn): R` has type `T1 -> … -> Tn -> R`; a
  constructor `C(F1, …, Fn)` of `T(vs)` has `F1 -> … -> Fn -> T(vs)`. A
  lambda's parameters take their annotations or fresh variables; lambdas
  are monomorphic (an unused `fn(x) => 1` is `_ -> Int`). `e(a1, …, aj)`
  is `e(a1)…(aj)`: applying a value whose type is Int, Bool, a declared
  type or a rigid variable is E_TYPE `Expected a function, found Int` at
  the first argument that does not fit. `a |> g(b1…bk)` is checked as
  `g(b1…bk, a)`, any other `a |> e` as `e(a)` (fn-check).
- Arity. A named function's declared parameter count (a constructor's
  field count) is its stage boundary. `f(a1…aj)` with j = n is a call;
  0 < j < n is partial application, a function value; j > n is
  over-application `f(a1…an)(…)`, E_ARITY `Wrong number of arguments` at
  the call when `f`'s declared result can never be a function, or, through
  a result variable, after `f`'s n arguments when its instantiated result
  is not one (fn-check, fn-run).
- Comparability and patterns. A type that mentions `->`, directly or
  through the fields of a declared type it names (to a fixed point:
  `type Outer = Outer(Box)` with `type Box = Box(Int -> Int)`), is not
  comparable: E_TYPE `Type Int -> Int is not comparable` (`Type Box(Int)
  is not comparable`), judged after the rigid and hole checks. On a
  function-typed scrutinee only `_` and binders fit (`Expected Int ->
  Int, found Int`). Function types are inhabited (fn-rules; rows
  `fun-compare`, `functional-fixpoint`).
- Hint. When an E_TYPE is reported anyway, the found expression is,
  through parentheses only, a direct partial application of a named
  function or constructor, and the expected type is not a function or an
  unsolved type variable (a signature's own variable does qualify), the
  message adds `; missing 1 argument to take?` (`missing 2
  arguments to …`); code, span and types are unchanged (fn-hint).
- Evaluation. Strict, left to right: `e(a1, …, aj)` evaluates `e`, `a1`,
  applies, `a2`, applies, and so on; a value's body runs exactly when an
  application completes its stage boundary: a named function or
  constructor at its declared arity, whatever its type (`use(stuck)` in
  ADR 008 enters `stuck` at `f(1)`), a lambda at its last parameter. A
  partial application evaluates its arguments at once, and a shared
  partial never re-evaluates them. A lambda captures the values of the
  locals it reads. `a |> e` evaluates `a` first, then `e`'s callee and
  arguments, then applies (fn-timing, which checks each of these on the
  generated Go and against the independent interpreter; fn-oracle
  compares generated higher-order programs; rows `stage-value`,
  `stage-lambda`, `partial-strict`, `pipe-order`, `block-order`,
  `lambda-capture`).
- Specialization. Every reference to a named function, called or bare,
  at any depth inside lambdas, is an edge of the instantiation rule, so
  `fn grow(x: a): Int = apply(fn(y) => grow(Cons(y, Nil)), x);` is
  E_SPECIALIZATION `Recursive call to grow changes its type arguments`;
  `->` in a type declaration's fields is a type constructor for the rule
  (fn-names, fn-specialize; rows `value-edge`, `arrow-key`).
- Scale. Long parameter lists and arrow spines cost Bumpus's phases
  linear time and no stack in their length (fn-linear, at 20,000 and
  80,000 parameters); generated Go builds within 10 s at 5,000
  parameters (fn-scale.serial). Functions are neither printed nor
  compared.

Nesting. One declaration body may nest at most 128 levels (ADR 006,
Format.Parse.Grammar `nestingLimit`). A level is a parenthesized expression,
an `if` condition or branch, a `match` scrutinee or arm body, a call or
constructor argument, a constructor-pattern field, a `+`, `|>` or
comparison operand, or (FN001) a lambda body or the parameter side of an
arrow; a postfix application chain nests its callee once (ADR 006,
fn-depth). Only one root-to-leaf path counts; siblings and later declarations
do not add up, and every function body starts at 0. Operators count the
depth of the tree they build: `a + b + c` is `(a + b) + c`, so a flat sum
of n operands counts n - 1 levels (129 operands compile, 130 do not), and
a deep left operand counts in full. Deeper input is E_NESTING `Nesting
exceeds 128 levels` at the token that would exceed the limit, never a stack
overflow (test/depth.test.mjs, through the CLI, for each form at 128 and
129). A flat sum without that bound is Proposed (BACKLOG O001).

Locations are half-open UTF-16 code-unit offsets, zero based; line/column one
based; LF increments line and resets column. Parenthesized expressions keep
the inner span. A diagnostic reports the first error in phase/traversal order.
E_INTERNAL is a compiler invariant failure. Codes are a closed ADT: E_LEX,
E_SYNTAX, E_INTEGER, E_ENTRY, E_DUPLICATE, E_UNBOUND, E_NOT_CALLABLE, E_TYPE,
E_ARITY, E_REDUNDANT, E_NON_EXHAUSTIVE, E_NESTING, E_SPECIALIZATION,
E_INTERNAL. The CLI adds
E_USAGE, E_IO and E_TOOL.
