# ADR 008: first-class functions, staged by declared arity

Accepted and implemented 2026-10-09 (milestone FN001, Tasks 1-9, branch
fn001). Binding spec: docs/plans/2026-10-08-functions-design.md (§1-§13
with Amendment A1 and the Task 4-6 clarifications); plan
docs/plans/2026-10-08-functions-plan.md; evidence docs/progress.md
("FN001 Task …"). Builds on ADR 007 (whole-program specialization) and
keeps ADR 001's strict, left-to-right evaluation.

## Context

Generic list functions (`map`, folds, pipelines) need functions as
values: function types, partial application, lambdas that capture
locals, and reverse application. Go generation stays monomorphic and
must keep today's Go for every program that uses none of these, and the
compiler's own phases must stay linear and stack-safe on declarations of
tens of thousands of parameters (test/large-source.test.mjs).

## Decision

### Types and syntax

`Domain.Type.Ty` has a curried binary arrow, `TFun`. `(A, B) -> C` is
notation for `A -> B -> C`; `->` is right-associative and its result side
adds no nesting level, so a long spine is one level (ADR 006). Lambdas
are `fn(x, y: T) => e`, monomorphic, annotations optional, `_` discards
an argument. `a |> e` binds looser than comparison and associates left.
Every pass over an arrow (unification, substitution, occurs, depth,
rendering, keys, Go types, the hand-written `Eq`/`Ord`) walks its result
spine by a loop.

### Staging by declared arity

A named function's declared parameter count (a constructor's field
count) is its stage boundary, and it survives every use as a value:
`f(a1…aj)` is a call when j = n, a strict partial application when
0 < j < n (arguments evaluated now, once), and over-application
`f(a1…an)(rest)` when j > n. Two functions of one type can differ in
timing: with `use(f) = drop1(f(1))`, `use(add)` returns but `use(stuck)`
enters `stuck` (test/fn-timing.test.mjs). A lambda's body runs exactly
when its last parameter is applied. No function or lambda is
eta-expanded. Rejected: one canonical uncurried `func(A, B) C` per type
with adapters (loses the timing above; regression row `stage-value`).

### Nested function values

A value of `A -> B -> C` is `func(A) bumpusFunN` with `bumpusFunN` the
named `func(B) C`; each stage boundary is an ordinary Go call boundary,
so Go's left-to-right call order is the source order and no runtime
arity check exists. In the monomorphic IR an arrow is a number,
`TFun FunTypeId`, into the program's hash-consed `funTypes` table, one
entry per spine suffix, a result numbered before the arrow holding it
(Features.Specialize.Intern); comparing two types is constant time and a
5,000-parameter arrow is 5,000 entries, not a tree copied into every
expression (the Task 5 review counted about 40 million arrow nodes the
other way). Go declares one named type per entry.

### Lowering: Amendment A1, rules 1-8

Nested Go closures for staged wrappers were measured first (Task 1:
`go build` 1.3 s at 50 parameters, 13.9 s at 200, 221 s at 300, unfinished
after 10 minutes at 1,000) and rejected; a copied environment struct is
O(n) per stage and also rejected. The adopted convention (design §13,
Format.Go.{Value, Stage, Entry, Lambda, Apply, Pipe}):

1. Direct saturated calls are today's n-ary Go call; a program without
   function values emits byte-identical Go (bootstrap/*.go).
2. One node type per distinct argument Go type,
   `struct { value A; previous any }`; each stage allocates one node.
3. A staged wrapper (arity n ≥ 2), once per specialization used as a
   value: `FValue` and top-level `FStage<k>`, each returning one closure
   that links a node and calls the next stage. Arity 1 needs none.
4. `FEntry` walks the chain once into per-type arrays (package-level kind
   and slot tables) and makes one n-ary call: the body exists once.
5. A lambda is lifted to an n-ary function of its free locals (ascending
   LocalId) and parameters; its value is that function's wrapper applied
   to the free locals.
6. Applying a value to j arguments is `h(a1)…(aj)`, cut beyond 64 into
   top-level helpers that evaluate each argument in place.
7. A pipe holds a non-trivial left operand in a lifted function's
   parameter, then applies with it last.
8. One named Go type per interned arrow suffix.

Task 1's round 3 (linked environment, shared body, one shared partial
completed twice), total `go build` seconds: 3.4 at 5,000 and 52.1 at
20,000 parameters with 3 distinct types; 5.1 and 80.0 with 1,000 types;
49-52 bytes per stage either way. Task 8's milestone built all eleven
20,000-parameter programs, the largest in 13.7 s against 100 s.

### Scale rule

Linearity is claimed for Bumpus phases only (test/fn-linear.test.mjs:
eight value forms at 20,000 parameters under three times their measured
time, and at 80,000 without stack failure). Generated Go is held to total
`go build` bounds per program: 10 s at 5,000 parameters in `npm run
verify`'s serial phase (test/fn-scale.serial.test.mjs, user decision A)
and 100 s at 20,000 in the milestone (scripts/fn-milestone.mjs, bodies
bounded: user decision B, BACKLOG G003).

### Pipe order

`a |> e` evaluates `a` first, then `e`'s callee and explicit arguments,
then applies with `g(b1…bk, a)`'s stage boundaries. `Pipe` stays a
distinct node through both IRs so lowering can order the operand first
(regression row `pipe-order`).

### Specialization and comparability

Every reference to a named function, called or bare, at any depth inside
lambdas, carries its instantiation and is a call-graph edge; ADR 007's
instantiation rule and finiteness proof apply unchanged (row
`value-edge`). Arrow types are interned by (parameter, result) numbers
(row `arrow-key`). A type that mentions an arrow, directly or through a
declared type's fields to a fixed point, is not comparable (rows
`fun-compare`, `functional-fixpoint`), nor printable: `main`'s result
must not hold a function.

### Hint provenance

An under-application is a value, not E_ARITY. When checking reports an
E_TYPE anyway and the found expression is, through parentheses only, a
direct partial application of a named function or constructor, and the
expected type is not a function or a meta, the message gains `; missing
<k> argument(s) to <f>?`. The hint never changes the code, span or types
and is computed after the failure without unification
(test/fn-hint.test.mjs).

### Diagnostics that changed

A bare function or constructor with fields is a value (was E_UNBOUND /
E_ARITY); a bare zero-parameter function is E_ARITY `Expected f()`;
calling a local with arguments is application, E_TYPE `Expected a
function, found T` when it is not one (`x()` stays E_NOT_CALLABLE);
over-application through a type variable checks the callee's arguments
first; a non-printable `main` is E_ENTRY `Expected fn main() with a
printable result type`. Over-application past a non-function result and
`f()` on a function with parameters keep E_ARITY `Wrong number of
arguments` (user decision). Each changed row is listed with old and new
code, span and text in its task's progress entry.

## Consequences

- Twenty-two regression rows (ten FN001: `stage-value`, `stage-lambda`,
  `partial-strict`, `pipe-order`, `lambda-capture`, `fun-compare`,
  `block-order`, `value-edge`, `functional-fixpoint`, `arrow-key`;
  scripts/regression-fn.mjs, test/regression-fn.mjs).
- The independent interpreter (test/poly-oracle.mjs) models staging,
  closures and pipes; generated higher-order programs compare against Go
  (test/fn-oracle.test.mjs).
- Applying a function value allocates one node and one closure per
  argument; a saturation optimization is deferred until measured.
- Follow-ups (BACKLOG): a local binding form, placeholder application,
  saturation optimization, I001 foreign wrappers declaring their arity,
  G002 (parser nesting headroom lost to the new layers), G003 (long
  operator chains in one Go expression), T002, T003.
