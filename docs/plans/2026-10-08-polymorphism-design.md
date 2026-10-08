# Rank-1 polymorphism and type parameters: design (P001)

Status: direction approved by the user in conversation 2026-10-08:
parameterized types are in scope; type variables are opaque (no built-in
comparison constraint); specialization is a separate pure phase (approach A).
The user's first written review (2026-10-08) gave conditional approval and
required revisions to the termination rule, the handling of unsolved
variables, and several precision points; section 12 maps each finding to
its resolution. The revised spec was approved 2026-10-08. Nothing is
implemented; the plan is docs/plans/2026-10-08-polymorphism-plan.md.

## Goal and non-goals

Goal: generic data types and generic functions that are useful without
type classes: `type List(a) = Nil | Cons(a, List(a));` with `length`,
`append`, `reverse`, `zip`, trees, `Maybe(a)`, `Pair(a, b)`, checked with
rank-1 schemes from mandatory signatures and occurs-checked unification,
and lowered by whole-program specialization (ADR 002) to ordinary
monomorphic Go.

Non-goals: classes, constraints, `derive`, a Prelude (C001; section 11);
comparing a value whose type contains a type variable; kinds, unapplied
constructors and HKTs (K001); polymorphic recursion and nested data types
(section 4); first-class functions or lambdas; type annotations inside
expressions; explicit `forall`; modules and separate compilation (M001).

Assumption: whole-program compilation. Every program is one file and Go is
generated only for what `main` and the monomorphic functions reach. When
separate compilation, exported functions or library artifacts arrive (M001),
reachability from `main` no longer determines what must be generated; that
is M001's design problem, not P001's.

Preserved: phase boundaries and the internal-IR allowlist discipline (now
two internal IRs, section 7); strict left-to-right evaluation; the
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
- A type application spans its head through its closing parenthesis.

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
  `TypeArguments String`) at the type reference. Phantom parameters are
  allowed.
- Function type variables are implicitly quantified over the whole
  signature: every lowercase name in the parameter and result types. A
  variable may appear only in the result (`fn loop(): a = loop();`).
- Constructors become polymorphic: `Nil : List(a)`, `Cons : (a, List(a)) →
  List(a)`. Global namespace rules are unchanged.
- `main` must have a ground result type (no type variable): E_ENTRY with
  new EntryKind `EntryPolymorphic`, message `Expected fn main() with a
  concrete result type`.

## 3. Types, rigid and flexible variables

Four representations, each with only the variables its phase may hold:

| Representation | Module | Variables it can hold |
|---|---|---|
| Source type | Domain.Resolved `Ty` | `TRigid VarId` (signature or declaration variable) |
| Checker type | Features.Check.Unify (private) | `TRigid VarId` and `TMeta MetaId` |
| Checked IR type | Domain.Checked.Internal `Ty` | `TRigid VarId` and `THole HoleId` |
| Monomorphic IR type | Domain.IR.Internal `Ty` | none: `TInt \| TBool \| TData TypeId` |

All four share `TInt`, `TBool` and `TData TypeId (Array Ty)` (the last
without arguments in the monomorphic IR, where each ground application has
its own TypeId).

- Rigid variables are the signature's variables inside their own function.
  A rigid variable unifies only with itself: `fn f(x: a): Int = x;` is
  E_TYPE (expected Int, found a); `fn g(x: a, y: b): a = y;` is E_TYPE.
- Flexible variables (metas) come from instantiating a scheme at a use:
  each use of a polymorphic function or constructor gets fresh metas, so
  `pair(id(1), id(true))` type-checks. A meta unifies with any type that
  does not contain it, including a rigid variable.
- Unification replaces every type equality the checker uses today
  (`require`, `if` branches, arm bodies, comparison operands, pattern
  types), in the current left-to-right order, so the first error and its
  span are today's for every monomorphic program.
- Occurs check: binding a meta to a type that properly contains it is
  E_TYPE with new Problem `InfiniteType TypeName TypeName`. Example: in
  `match Nil { Cons(h, t) => same(h, t), Nil => 0 }` with
  `fn same(x: a, y: a): Int`, `h : m` and `t : List(m)`.
- `TypeName` (Domain.Problem) gains `AppliedName String (Array TypeName)`,
  `VariableName String` and `HoleName` (a meta in a message, rendered `_`).
  Format renders `List(Pair(Int, a))`.

Unsolved metas. After a function's body is checked, each meta still unbound
becomes a hole in the checked IR (`THole`, numbered per function). Checking
does not choose a type for it; there is no language-level default.
Specialization later substitutes a representative (section 6).

Comparison. Both operands unify as today. After the function is checked,
each comparison's operand type, fully substituted, must be ground: a rigid
variable in it is E_TYPE with new Problem `NotComparable TypeName`
(`fn same(x: a, y: a): Bool = x == y;`, and `List(a) == List(a)`); a hole
in it is E_TYPE with new Problem `AmbiguousType TypeName` (`Nil == Nil`).
Both at the left operand. The second rejection is deliberate: under C001,
comparison becomes an Ord use, and an Ord use at an undetermined type is an
ambiguity error, so rejecting it now keeps C001 additive.

Patterns. On a scrutinee whose type is a rigid variable or a hole, only `_`
and binders fit; a constructor or literal pattern is E_TYPE as today.

## 4. Finite specialization

Specialization creates one copy per key `(declaration, ground type
arguments)`. This section gives the rule that makes the set of keys finite
and its proof; the 10,000 limit (section 6) is a resource guard, never the
termination argument.

### 4.1 The rule (checked in Features.Check, after typing)

Build two graphs: the call graph over functions (an edge for each call)
and the reference graph over type declarations (an edge for each occurrence
of a declared type anywhere inside a constructor field type, including
inside another type's arguments). Take strongly connected components of
each separately.

Instantiation rule. The rule is applied after the referring function is
checked, when each of its metas is either solved or a hole. At every
reference from a member of a component to a member of the same component,
each type argument, fully substituted, must be one of:

1. a bare rigid variable of the referring declaration, or
2. a ground type: no rigid variable; a hole counts as ground, because
   specialization replaces it with a fixed ground type.

A type that applies a constructor to an argument containing a variable,
such as `List(a)` or `Pair(Int, a)`, is neither, and is rejected.

Diagnostics, both new ErrorCode `E_SPECIALIZATION`, at the reference's
span, naming the referenced declaration:
- functions: Problem `PolymorphicRecursion String`;
  `fn f(x: a): Int = f(Cons(x, Nil));`;
- types: Problem `NestedDatatype String`;
  `type Nest(a) = Nil | Cons(a, Nest(List(a)));`.

### 4.2 Proof of finiteness

Functions. Fix a component C and an entering key `(d0, τ̄0)` with τ̄0
ground. Let `G_C` be the finite set of ground types written as type
arguments at intra-component references in C (holes included, as their
representative), and `T = components(τ̄0) ∪ G_C`. Claim: every key reached
from `(d0, τ̄0)` through intra-component references has all its arguments
in T. Induction on the path length: the entry satisfies it; at a key
`(d, σ̄)` with σ̄ in T, a reference from d to d' in C has each argument
either a rigid variable v_i of d, instantiated to σ_i ∈ T, or a ground
type in G_C ⊆ T. So C contributes at most `Σ_{d ∈ C} |T|^{arity(d)}` keys
per entering key. Components form a DAG; each key's body has finitely many
references, so each component receives finitely many entering keys from
the components above it (induction in topological order, starting from the
finite seeds: the monomorphic functions). Hence finitely many keys.

Types. The same argument, over the reference graph, bounds the ground type
applications reachable by unfolding constructor fields from any ground
application; specialization of types and inhabitedness (section 5) both
rely on it. Each key's function body mentions finitely many types, so the
type applications needed by finitely many function keys are finite too.

Swapping (`f(a, b)` calls `g(b, a)`), dropping (`f(a, b)` calls `g(a)`),
concrete substitution (`f(a, b)` calls `g(a, Int)` and `g(a, b)` calls
`f(b, a)`) and ordinary `List(a)` recursion (`length(t)`; the field
`List(a)`) are all accepted. `f(a)` calls `g(List(a))` with `g(a)` calling
`f(a)` is rejected at the first call.

### 4.3 Conservatism

The rule rejects some finite programs: `f(a)` calls `g(List(a))` and
`g(b)` calls `f(Int)` is finite but rejected. The exact criterion is the
absence of an expanding cycle in the component's instantiation graph (the
check C# and the CLI apply to generic type definitions). P001 takes the
simpler rule; relaxing it later rejects nothing that is accepted today.

## 5. Coverage and inhabitedness

Coverage runs on the checked polymorphic IR, once per source match, so
each E_NON_EXHAUSTIVE or E_REDUNDANT is reported once, at its source span,
and source correctness does not depend on which specializations are
reachable.

- Column types are applied types: a constructor's field types are its
  declared field types with the type's arguments substituted.
- Rigid variables and holes are abstract types: no complete head set (like
  Int), so only `_` or a binder covers such a column; they are assumed
  inhabited, since a caller may choose an inhabited type. A match over
  `List(a)` with `Nil` and `Cons(_, _)` is exhaustive whatever `a` is.
- Inhabitedness is computed per type application, memoized over the finite
  set of applications reachable from it (section 4.2). `Maybe(Void)` has
  only `Nothing` inhabited, so a `Just(_)` arm on it follows the existing
  uninhabited-arm policy (ADR 003).
- Witnesses keep their format (constructor names only).

## 6. Specialization

Features.Specialize (new, pure) consumes the checked IR and produces the
monomorphic IR.

- Keys are `(declaration id, Array GroundTy)` for functions and types,
  compared structurally (an `Eq`/`Ord` instance on the ground type ADT),
  never by printed names. Every key is generated at most once (memo table).
- Worklist: seeds are every monomorphic function, in id order (all are
  emitted today, used or not). Each copied body is walked in pre-order,
  left to right; each new key is appended first-in first-out. Output ids are
  dense: monomorphic types and functions keep their relative order and come
  first, then specialized types and functions in discovery order.
- A polymorphic declaration that is never instantiated is checked but not
  emitted (whole-program assumption above).
- Identity: on a program with no type parameters or variables, Specialize
  returns its input unchanged, so the Go bytes are unchanged.
- Holes: each hole is replaced by one fixed representative, Int. This is a
  specialization detail, not a typing rule. It is valid in P001 because:
  1. no constraint can mention a hole (P001 has no constraints; C001 must
     report a constrained hole as ambiguous, never pick a representative);
  2. no comparison is made at a type containing a hole (section 3);
  3. `main`'s result is ground (section 2);
  4. no P001 operation depends on a type argument: there are no classes,
     no type case and no FFI, and lowering of every construct is uniform in
     the element type. So a program's output is the same for any ground
     representative. Section 8 tests this directly rather than relying on
     the argument alone.
  `length(Nil)` thus specializes to the same key as `length` at Int.
- Limit: Specialize fails with E_SPECIALIZATION, Problem
  `SpecializationLimit Int`, when the number of keys created from
  polymorphic declarations would exceed 10,000 (a named constant, global).
  Counted: each instantiation of a function with type variables and each
  ground application of a type with parameters, together. Not counted:
  monomorphic functions and types, so existing large monomorphic programs
  are unaffected. Plan review 2026-10-08 fixed this accounting. The span is the reference (call, construction or type
  reference) that would create the first key over the limit.
- Go names stay numeric (`bumpusTy7`, `bumpusFn12`, `bumpusFn12Match1`).
  Printed values use source constructor names, so `Cons(1, Nil)` prints and
  re-reads as today.

## 7. Phases, IR and module boundaries

Pipeline: Parse → Resolve → Check (types, section 4 rule, comparison
groundness, coverage) → Specialize → Go.

- Domain.Checked.Internal (new): the checked polymorphic IR. Each call and
  construction records its instantiation (types over the caller's rigid
  variables and holes). Constructors visible only to Features.Check* and
  Features.Specialize.
- Domain.IR.Internal (existing): the monomorphic IR Format.Go consumes, with
  the variable-free `Ty` of section 3, so a type variable cannot reach Go
  generation by construction rather than by assertion. Constructors visible
  only to Features.Specialize and Format.Go*. Format.Go changes only its
  imports.
- scripts/structure.mjs, AGENTS.md and docs/engineering.md change the IR
  gate from one allowlist to two. Program.Compile calls Specialize between
  Check and Go.

## 8. Testing and proofs

Every rejection row asserts exact code, span and text.

- Syntax and declarations: each E_SYNTAX form of section 1; unbound and
  duplicate type parameters; wrong argument counts, including bare `List`;
  polymorphic `main`.
- Rigid and flexible variables, tested on the unifier directly: rigid `a`
  against Int fails; rigid `a` against rigid `b` fails; rigid `a` against
  itself succeeds; a meta against Int, against rigid `a`, and against
  `List(a)` succeeds; a meta against a type properly containing it fails.
  Source rows for each through the CLI.
- Typing rows: two instantiations in one expression; occurs check;
  `NotComparable` on `a` and `List(a)`; `AmbiguousType` on `Nil == Nil`;
  constructor pattern on a variable scrutinee; the existing diagnostics
  characterization unchanged.
- Unification properties over generated types and constructor signatures:
  a successful unifier `s` makes both sides equal; `s` is idempotent;
  applying a composition equals applying in sequence; most-general: for
  pairs made unifiable by applying a generated substitution σ, unification
  succeeds and `σ(s(t)) = σ(t)` on both sides. Reference comparison: an
  independent JavaScript unifier (test/unify-oracle.mjs, union-find,
  written separately) agrees on success and, up to renaming, on the result.
- Instantiation rule rows: each accepted and rejected example of section
  4, for functions and for types separately.
- Finite-component termination, generated: programs whose components mix
  variable permutation, argument dropping, ground substitution and mutual
  recursion, at random entry keys. Each specializes, and its key count per
  component is at most the section 4.2 bound computed independently by the
  test. Generated programs that add one wrapping argument (`List(v)`) at an
  intra-component reference are rejected with E_SPECIALIZATION.
- Specialization uniqueness: no two output declarations share a key
  (Specialize exposes its key table to tests).
- Specialization determinism: compiling twice gives equal bytes; permuting
  declaration order gives the same output and the same key set up to
  renumbering.
- Representative independence: generated programs with holes, specialized
  once with Int and once with Bool as representative (a test-only argument
  to the pure function), print the same output.
- Execution oracle: generated polymorphic programs (generic functions over
  generated parameterized types, instantiated at generated ground types,
  including nested applications) run in Go and match the independent
  reference interpreter (extended to parse the new type syntax; it
  evaluates without types). This checks that specialization preserves
  meaning.
- Identity: every existing test program and generated monomorphic program
  specializes to itself (structural equality on the IR); the three
  bootstrap snapshots stay byte-identical.
- Coverage rows: `Maybe(Void)` arms; generic matches over `List(a)`;
  matches over a bare `a`; witnesses through type arguments; one diagnostic
  per source match even when instantiated twice.
- Limit: a generated program just under the limit compiles; one key over
  fails with E_SPECIALIZATION at the stated span.
- Snapshot: examples/lists.bumpus (section 9) as bootstrap/lists.go.
- Regression rows (scripts/regression.mjs, isolated copies), each with a
  probe that passes healthy and fails on its mutant: `occurs` (occurs check
  removed); `rigid` (a rigid variable unifies with Int); `instantiate`
  (metas shared across uses of one scheme); `spec-key` (key compares only
  each argument's outermost constructor; the probe uses
  `List(List(Int))` and `List(List(Bool))` together, so the two share a Go
  type and the probe fails).
- Scale: large-source gains a program with thousands of distinct
  instantiations, with a time bound that fails a quadratic worklist.

## 9. Usefulness without classes

examples/lists.bumpus doubles as documentation and as the seed of a future
Prelude: `length`, `append`, `reverse`, `zip`, `headOr(xs, d)`, `last` as
`Maybe(a)`, `take`/`drop` by Int, `fromMaybe`, `fst`/`snd`, `swap`, tree
`size`, `depth` and `flatten`, `Either(a, b)` selection by match. A total
`head(xs: List(a)): a` cannot be written (no value of `a` exists for
`Nil`); `headOr` and `Maybe(a)` are the total forms. With no first-class
functions, `map` and folds are written per use; that limit belongs to a
later functions milestone, not P001.

## 10. Decisions

1. Parameterized types are part of P001.
2. Type variables are opaque; no built-in `Ord`; comparison requires a
   ground operand type (no rigid variable, no hole).
3. Approach A: a separate pure Specialize phase; Format.Go stays
   monomorphic. Rejected: specializing inside Format.Go (breaks phase
   separation) and Go generics (ADR 002; cannot express future
   constructor variables).
4. Lowercase implicit variables and parenthesized application.
5. The instantiation rule of section 4, separately for functions and
   types, with its proof; the limit is a resource guard only.
6. Unsolved metas become holes; Specialize picks a representative under
   the conditions of section 6. No typing-level default.
7. Coverage on the polymorphic IR; rigid variables and holes abstract and
   inhabited.
8. Byte-identical output for monomorphic programs; whole-program
   compilation assumed.

## 11. Relation to C001 (direction, not a settled design)

The user's direction 2026-10-08: C001 brings a Bumpus Prelude in which Eq
and Ord are ordinary classes (no compiler special case); `derive` exists;
default Ord instances come from the Prelude and can be opted out of by
hiding imports or similar; a type may have several instances, in the fp-ts
style, without Haskell newtypes. ADR 002's one-instance-per-type clause is
dropped. This makes instance identity, not only type identity, part of the
semantics: two Ord instances for one type can order it differently, and a
collection built under one must not be used as if built under the other.
Dictionary selection and instance identity are open questions for C001's
own design; nothing here settles them. P001 prepares only by keeping
variables opaque, rejecting comparison at undetermined types, recording
instantiations in the checked IR (where evidence will attach), and keeping
holes out of any constrained position.

## 12. Review resolutions (2026-10-08)

| Finding | Resolution |
|---|---|
| 1. Termination rule needs a proof; separate functions from types | Section 4: rule stated over substituted arguments; ground means no variable at all; separate graphs, components and diagnostics for functions and types; proof in 4.2; conservatism and the exact criterion in 4.3; generated termination tests with the computed bound (section 8). |
| 2. Int default not generally semantics-preserving | No typing default. Unsolved metas become holes in the checked IR; Specialize picks a representative under four stated conditions (section 6); comparison at a hole type is rejected now so C001 stays additive; a representative-independence property test. |
| 3. Distinguish rigid and flexible variables explicitly | Section 3 table: each phase's type admits only its variables; unifier tests for every rigid/flexible pair. |
| 4. Variable-free monomorphic IR; structural keys | Monomorphic `Ty` has no variable constructor; keys are structural over the full argument vector (section 6). |
| 5. Rigid variables abstract in coverage | Section 5, holes included. |
| 6. Whole-program assumption | Stated under Goal and non-goals. |
| 7. Determinism, uniqueness, termination tests; limit scope; spec-key probe | Section 8; limit global with code and span (section 6); spec-key probe on nested arguments. |
| 8. C001 not settled | Section 11 retitled and reworded; instance identity named as C001's open question. |
