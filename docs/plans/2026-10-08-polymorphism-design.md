# Rank-1 polymorphism and type parameters: design (P001)

Status: direction approved by the user in conversation 2026-10-08:
parameterized types are in scope; type variables are opaque (no built-in
comparison constraint); specialization is a separate pure phase (approach A)
with the five defaults of section 9. The written spec awaits the user's
review. Nothing here is implemented yet.

## Goal and non-goals

Goal: generic data types and generic functions that are useful without
type classes: `type List(a) = Nil | Cons(a, List(a));` with `length`,
`append`, `reverse`, `zip`, trees, `Maybe(a)`, `Pair(a, b)`, checked with
rank-1 schemes from mandatory signatures and occurs-checked unification,
and lowered by whole-program specialization (ADR 002) to ordinary
monomorphic Go.

Non-goals: classes, constraints, `derive`, a Prelude (C001; section 10);
comparing or printing a value whose type contains a signature type variable;
kinds, unapplied constructors and HKTs (K001); polymorphic recursion and
non-regular data types (section 4); first-class functions or lambdas;
type annotations inside expressions; explicit `forall`; modules (M001).

Preserved: phase boundaries and the internal-IR allowlist discipline (now
two internal IRs, section 6); strict left-to-right evaluation; the
structural order and print format of ADR 005; every existing diagnostic's
code, span and text. A program that declares no type parameters and
mentions no type variable emits byte-identical Go: bootstrap/answer.go,
shapes.go and tree.go are unchanged.

## 1. Syntax

```ebnf
typedecl  = "type", upper, [ "(", lower, { ",", lower }, ")" ], "=",
            ctor, { "|", ctor }, ";" ;
type      = "Int" | "Bool" | lower
          | upper, [ "(", type, { ",", type }, ")" ] ;
```

- A lowercase name in a type is a type variable. No new reserved words.
- `type T() = …`, `List()`, `Int(a)`, `Bool(a)` and `a(Int)` are E_SYNTAX.
- Type arguments nest under the existing E_NESTING bound (ADR 006).
- Spans: a type application spans its head through its closing parenthesis.

Examples:

```
type List(a) = Nil | Cons(a, List(a));
type Pair(a, b) = Pair(a, b);
fn length(xs: List(a)): Int = match xs { Nil => 0, Cons(_, t) => 1 + length(t) };
fn zip(xs: List(a), ys: List(b)): List(Pair(a, b)) = …;
```

## 2. Names and declarations

- Type parameters scope over their own declaration's constructors. A field
  type naming a variable that is not a parameter is E_UNBOUND (new
  UnboundKind `UnboundTypeVariable`). A repeated parameter is E_DUPLICATE
  (new DuplicateKind `DuplicateTypeParameter`).
- A declared type used with the wrong number of arguments, including none
  where it has parameters (`List`), is E_ARITY (new Problem
  `TypeArguments String`), reported at the type reference. Unused
  (phantom) parameters are allowed.
- Function type variables are implicitly quantified over the whole
  signature: every lowercase name in the parameter and result types. A
  variable may appear only in the result (`fn loop(): a = loop();`).
- Constructors become polymorphic: `Nil : List(a)`, `Cons : (a, List(a)) →
  List(a)`. The global namespace rules are unchanged.
- `main` must have no type variable in its result: E_ENTRY with new
  EntryKind `EntryPolymorphic`, message `Expected fn main() with a concrete
  result type`.

## 3. Typing

Representation (Domain.Resolved): `data Ty = TInt | TBool | TData TypeId
(Array Ty) | TVar VarId`, where `VarId` indexes the enclosing declaration's
variables (names kept beside it for diagnostics). Unification variables
(metas) never leave Features.Check.

- Each signature variable is rigid inside its function: it unifies only with
  itself. `fn f(x: a): Int = x;` is E_TYPE (expected Int, found a).
- Each use of a polymorphic function or constructor instantiates its
  scheme with fresh metas; `pair(id(1), id(true))` type-checks.
- Every place the checker now compares types (`require`, `if` branches,
  arm bodies, comparison operands, pattern types) unifies instead, in the
  current left-to-right order, so the first error and its span are those
  of today's checker for monomorphic programs.
- Occurs check: binding a meta to a type that contains it is E_TYPE with
  new Problem `InfiniteType TypeName TypeName`. Example: in
  `match Nil { Cons(h, t) => same(h, t), Nil => 0 }` with
  `fn same(x: a, y: a): Int`, `h : m` and `t : List(m)`.
- Comparison: both operands unify as today; then if the operand type
  contains a rigid variable, E_TYPE with new Problem `NotComparable
  TypeName` at the left operand. `List(a) == List(a)` is rejected; this
  is what keeps variables opaque (the ground for C001's constraints).
- Patterns on a rigid-variable scrutinee: only `_` and binders fit; a
  constructor or literal pattern is E_TYPE as today.
- Defaulting: after a function is checked, every unsolved meta in it is
  set to Int. Metas cannot escape a function (signatures are mandatory),
  and no value of an unsolved meta's type is ever produced at run time
  (only a call that never returns, or an unreachable binder, has that
  type), so the choice is unobservable: `length(Nil)` is 0 and `Nil ==
  Nil` holds whatever the element type. With C001, an unsolved meta under a constraint becomes an
  ambiguity error instead.
- `TypeName` (Domain.Problem) gains `AppliedName String (Array TypeName)`,
  `VariableName String` and `HoleName` (an unsolved meta in a message,
  rendered `_`). Format renders `List(Pair(Int, a))`.

## 4. Termination: the SCC instantiation rule

ADR 002 requires finite specialization. One rule covers functions and data
types. Take the strongly connected components of the call graph (functions)
and of the reference graph (type declarations' field types). Within a
component, every type argument at a reference to a member of the same
component must be either a type variable of the referring declaration or a
closed type (no variables).

- Allowed: `length(t)` in `length`; mutual `even`/`odd` over `List(a)`;
  `type Rose(a) = Node(a, Forest(a)); type Forest(a) = Empty | More(Rose(a),
  Forest(a));`; `type T(a, b) = C(T(b, a))` (a permutation); a recursive call
  at `List(Int)`.
- Rejected: `fn f(x: a): Int = f(Cons(x, Nil));` (polymorphic recursion)
  and `type Nest(a) = Nil | Cons(a, Nest(List(a)));` (non-regular). New
  ErrorCode `E_SPECIALIZATION`, Problem `ExpandingInstantiation String`
  naming the reference's target, at the reference's span.
- Why finite: inside a component, the instantiations reachable from one
  entry key are built from that key's arguments and the component's closed
  types, so a component contributes finitely many keys per entering key, and
  components form a DAG.
- Backstop: specialization stops with E_SPECIALIZATION (Problem
  `SpecializationLimit Int`) at `main`'s span when it would create more
  than a named limit of 10,000 specialized functions plus types. The rule
  above makes this a size budget, not a termination guard; the limit is
  measured against the large-source tests before being fixed.

The rule is checked in Features.Check after typing (call instantiations are
known then) and before coverage.

## 5. Coverage and inhabitedness

Coverage runs on the polymorphic checked IR, once per source match, so
each E_NON_EXHAUSTIVE or E_REDUNDANT is reported once, at its source span,
not once per specialization.

- Column types are applied types: a constructor's field types are its
  declared field types with the type's arguments substituted.
- A rigid variable column has no complete head set (like Int): only a
  wildcard or binder covers it.
- Inhabitedness becomes per type application, not per constructor:
  a variable is inhabited (a caller may choose Int); `Maybe(Void)` has
  only `Nothing` inhabited, so a `Just(_)` arm on a `Maybe(Void)` scrutinee
  follows the existing uninhabited-arm policy (ADR 003). The fixpoint is
  memoized over the finite set of applications reachable from a type,
  finite by section 4.
- Witnesses keep their format (constructor names only).

## 6. Phases, IR and module boundaries

Pipeline: Parse → Resolve → Check (types, section 4 rule, coverage) →
**Specialize** → Go.

- Domain.Checked.Internal (new): the checked polymorphic IR. Each call and
  construction records its instantiation (closed after defaulting, except
  for the caller's own rigid variables). Constructors visible only to
  Features.Check* and Features.Specialize.
- Domain.IR.Internal (existing): stays the monomorphic IR that Format.Go
  consumes. It gets its own `Ty = TInt | TBool | TData TypeId`, so a type
  variable cannot reach Go generation by construction. Constructors
  visible only to Features.Specialize and Format.Go*. Format.Go changes
  only its imports.
- Features.Specialize (new, pure): a worklist over keys `(declaration id,
  closed type arguments)`. Seeds: every monomorphic function, in id order
  (all are emitted today, used or not). Keys are discovered by a pre-order,
  left-to-right walk of each body, appended first-in first-out, memoized.
  Output ids are dense: monomorphic types and functions keep their relative
  order and come first, then specializations in discovery order. A
  polymorphic declaration that is never instantiated is checked but not
  emitted.
- Identity: on a program with no type parameters or variables, Specialize
  returns the same program, which gives byte-identical Go.
- Go names stay numeric (`bumpusTy7`, `bumpusFn12`, `bumpusFn12Match1`);
  printed values use source constructor names, so `Cons(1, Nil)` prints
  and re-reads as today.
- scripts/structure.mjs, AGENTS.md and docs/engineering.md change the IR
  gate from one allowlist to two (above). Program.Compile calls Specialize
  between Check and Go.

## 7. Testing and proofs

Every rejection row asserts exact code, span and text (test/poly-*.test.mjs).

- Syntax and declaration rows: each E_SYNTAX form of section 1; unbound and
  duplicate type parameters; wrong argument counts, including bare `List`;
  polymorphic `main`.
- Typing rows: rigid mismatch; two instantiations in one expression; occurs
  check; `NotComparable` on `a` and on `List(a)`; constructor pattern on a
  variable scrutinee; error order and spans unchanged on monomorphic
  programs (the existing diagnostics characterization still passes).
- SCC rule rows: each allowed and rejected example of section 4, plus the
  budget at a generated program over and under the limit.
- Unification properties (on the compiled PureScript unifier, loaded from
  output/ as other tests do), over generated types with a generated
  constructor signature: a successful unifier `s` makes both sides equal;
  `s` is idempotent; applying a composition equals applying in sequence;
  a meta against a proper type containing it fails; most-general: for
  pairs made unifiable by applying a generated substitution σ, unification
  succeeds and `σ(s(t)) = σ(t)` on both sides.
- Reference comparison: an independent JavaScript unifier
  (test/unify-oracle.mjs, union-find, written separately) agrees on success
  and, up to renaming of metas, on the unified type.
- Execution oracle: generated polymorphic programs (generic functions over
  generated parameterized types, instantiated at generated closed types,
  including nested applications) run in Go and match the independent
  reference interpreter (extended to parse the new type syntax; it
  evaluates without types); this is the
  check that specialization preserves meaning.
- Identity: every existing test program and generated monomorphic program
  specializes to itself (structural equality on the IR), and the three
  bootstrap snapshots stay byte-identical.
- Determinism and snapshot: a new examples/lists.bumpus (List, Maybe,
  Pair, Tree, the functions of section 8) compiles twice to equal bytes and
  is snapshotted as bootstrap/lists.go.
- Coverage rows: `Maybe(Void)` arms; generic matches; witnesses through
  type arguments; one diagnostic per source match even when instantiated
  twice.
- Regression rows (scripts/regression.mjs, isolated copies), each with a
  probe that passes healthy and fails on the mutant: `occurs` (occurs check
  removed), `rigid` (a rigid variable unifies with Int), `instantiate`
  (metas shared across uses of one scheme), `spec-key` (the key ignores
  type arguments, so `List(Int)` and `List(Bool)` share a Go type).
- Scale: large-source gains a program with thousands of distinct
  instantiations, with a time bound that fails a quadratic worklist.

## 8. Usefulness without classes

examples/lists.bumpus doubles as documentation and as the seed of a future
Prelude: `length`, `append`, `reverse`, `zip`, `headOr(xs, d)`, `last`,
`take`/`drop` by Int, `fromMaybe`, `fst`/`snd`, `swap`, tree `size`,
`depth` and `flatten`, `Either(a, b)` with `either`-style selection by
match. With no first-class functions, `map` and folds are written per use;
that limit belongs to a later functions milestone, not P001.

## 9. Decisions approved in conversation

1. Parameterized types are part of P001.
2. Type variables are opaque; no built-in `Ord`; comparing a type that
   contains a signature variable is E_TYPE.
3. Approach A: a separate pure Specialize phase; Format.Go stays
   monomorphic. Rejected: specializing inside Format.Go (breaks phase
   separation) and Go generics (ADR 002; cannot express future
   constructor variables).
4. Defaults: lowercase implicit variables and parenthesized application;
   the SCC rule; unsolved metas default to Int; coverage on polymorphic IR
   with variables inhabited; byte-identical output for monomorphic programs.

## 10. Relation to C001 (recorded, not built here)

The user's direction 2026-10-08: C001 brings a Bumpus Prelude in which
Eq and Ord are ordinary classes (no compiler special case); `derive`
exists; default Ord instances come from the Prelude and can be opted out
of by hiding imports or similar; a type may have several instances, in the
fp-ts style, without Haskell newtypes. The one-instance-per-type
(global coherence) requirement in ADR 002 is dropped; C001's ADR replaces
that clause and must say how a value built under one instance is kept from
use under another. P001 prepares for this only by keeping variables opaque
and by recording instantiations in the checked IR, where C001's evidence
will attach.

## 11. Documentation

docs/language.md (grammar, scoping, typing, the SCC rule, defaulting);
new ADR 007 (specialization phase, SCC rule, defaulting, opaque variables);
ADR 002 dated note on the dropped coherence clause; architecture.md (two
IRs, Specialize); engineering.md and AGENTS.md (IR gate); BACKLOG (P001,
C001 direction); progress, findings, next-session.
