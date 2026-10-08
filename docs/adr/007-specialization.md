# ADR 007: rank-1 polymorphism by whole-program specialization

Accepted and implemented 2026-10-08 (milestone P001, Tasks 1-9, branch
p001). Binding spec: docs/plans/2026-10-08-polymorphism-design.md
(sections 3-7); plan docs/plans/2026-10-08-polymorphism-plan.md. This ADR
records what was built and the decisions taken during execution (rulings
R1-R20 in the plan's execution ledger). It refines ADR 002's strategy
(specialize to monomorphic Go, no Go generics).

## Context

P001 adds parameterized types (`type List(a) = Nil | Cons(a, List(a));`)
and functions whose signatures mention lowercase type variables
(`fn length(xs: List(a)): Int`). Go generation stays monomorphic: every
generic declaration must become one Go declaration per ground type
argument vector it is used at, and that set must be finite and computed
deterministically from the program alone (whole-program assumption; M001
revisits it).

## Decision

### Phases

Parse → Resolve → Check → Specialize → Go. Check is, in order: typing
(rank-1 schemes from the mandatory signatures, occurs-checked unification,
comparison groundness and the inferred-type depth bound, per function),
the instantiation rule over the whole typed program, then coverage over
applied types. Specialize (Features.Specialize*) is a separate pure phase
from the checked polymorphic IR (Domain.Checked.Internal, types over rigid
variables and holes) to the monomorphic IR (Domain.IR.Internal, whose
`Ty` has no variable constructor, so a type variable cannot reach Go by
construction). Two importer allowlists guard the IRs (scripts/structure.mjs;
docs/engineering.md). Rejected: specializing inside Format.Go (mixes
phases) and Go generics (ADR 002).

### Typing

A signature's variables are rigid inside its own function: they unify only
with themselves. Each use of a function or constructor instantiates its
scheme with fresh metas (flexible variables). A meta binds to any type that
does not properly contain it; otherwise E_TYPE `Infinite type: _ occurs in
List(_)` (Features.Check.Unify, test/unify.test.mjs, poly-check). Each call
and construction records its instantiation in the checked IR.

### Holes and the representative

A meta still unbound when its function is checked becomes a hole, numbered
per function. Checking picks no type for it: there is no typing default.
Specialize replaces every hole with one representative, Int
(`specializeWith` takes another, for tests). This is valid in P001 because
all four conditions of spec §6 hold:

1. no constraint can mention a hole (P001 has no constraints; C001 must
   report a constrained hole as ambiguous, never pick a representative);
2. no comparison is made at a type containing a hole (comparison
   groundness, below);
3. `main`'s result is ground (E_ENTRY otherwise);
4. no operation depends on a type argument (no classes, type case or FFI;
   lowering is uniform in the element type).

test/poly-properties.test.mjs checks the consequence directly: 30
generated programs with holes emit different Go with Int and with Bool as
representative and print the same.

### Opaque variables and comparison groundness

Type variables are opaque: no built-in comparison constraint. After a
function is checked, every comparison's operand type, fully substituted,
must be ground. A rigid variable is E_TYPE `Type a is not comparable`; a
hole is E_TYPE `Ambiguous type List(_) in comparison` (left operand,
pre-order; a rigid variable is reported before a hole, ruling R9). The
second rejection keeps C001 additive: under C001 a comparison becomes an
Ord use, and an Ord use at an undetermined type is ambiguous. On a
scrutinee of variable or hole type only `_` and binders fit. Coverage
treats rigid variables and holes as abstract, inhabited types.

### The instantiation rule

Spec §4.1: in each strongly connected component of the call graph, and
separately of the type reference graph, every type argument at an
intra-component reference, fully substituted, must be a bare rigid
variable of the referrer or ground (a hole counts as ground). Otherwise
E_SPECIALIZATION `Recursive call to f changes its type arguments` or
`Recursive use of T changes its type arguments`. Spec §4.2 proves that
the rule makes the set of keys finite: per entering key a component
contributes at most Σ_{d ∈ C} |T|^arity(d) keys, T being the entry's
argument components plus the ground arguments written inside C, and the
component DAG has finitely many entering keys. test/poly-properties checks
that bound on 200 generated components.

The rule is conservative (spec §4.3): `f(a)` calling `g(List(a))` with
`g(b)` calling `f(Int)` is finite but rejected. The exact criterion is the
absence of an expanding cycle in the instantiation graph; relaxing to it
later rejects nothing accepted now. Types are judged before functions
(R11).

### Inferred-type depth bound (ruling R7)

Source types are bounded by the nesting limit (ADR 006), but composition
can infer far deeper types: `fn deep(x: a): L^127(a)` nested 44 deep
overflowed the stack in unification (RangeError, a crash on a legal
program). The compiler must never crash on a legal program, so checking
rejects any inferred type deeper than `inferredTypeLimit = 1000`
(Features.Check.Unify) with E_NESTING `Inferred type nesting exceeds 1000
levels`, at the expression whose type would exceed it. `exceedsLimit` is
an explicit-stack walk that stops past the limit, so the test itself is
stack-safe. It runs on each expression's type when built, on both operands
before each unification and on each binding before the occurs check
resolves it; unification also carries a level and fails past the limit;
every type of a finished body is bounded again before it is resolved.

Measured margins (warm Node, default stack): unify overflowed
between 2,218 and 2,250 levels in unit context and between 1,525 and about
1,779 inside the checker; resolve between 5,081 and about 5,589. The bound
leaves at least a 1.5x margin. It assumes Node's default stack: with
`--stack-size=400` near-limit message rendering overflows. Evidence:
test/poly-depth.test.mjs, test/unify.test.mjs; BACKLOG E006. Three review
rounds were needed (docs/findings.md).

### Specialization

Keys are `(declaration, ground arguments)` for functions and types. A
first-in first-out worklist is seeded with every monomorphic type, then
every monomorphic function, in id order; each copied body is walked in
pre-order (signature, an expression's type, a call's instantiation, its
callee, its arguments), and a key is created on first reference (R16).
Monomorphic declarations take the first output ids in their order, so a
program without type parameters or variables comes out unchanged and its
Go is byte-identical (bootstrap/answer.go, shapes.go, tree.go). A
polymorphic declaration never reached is not emitted.

Keys are hash-consed (ruling R15): each ground application is numbered
once as an output type, so a type key is `(TypeId, argument numbers)` and
a function key `(declaration, argument numbers)`; comparing two keys costs
their arity, never the size of the types they stand for. Keys are still
compared structurally, never by printed names. The `spec-key` regression
row merges `List(List(Int))` with `List(List(Bool))` and fails.

FN001 Task 5 extends this to arrows (Features.Specialize.Intern): a key
argument is Int, Bool, an output type's number or an arrow's number, and
arrows are hash-consed as (parameter number, result number), so each
suffix of a spine is numbered once, while its type is lowered, and two
5,000-parameter function types differing only in their last parameter
compare in constant time (test/fn-specialize.test.mjs: 0.23 s, against
5.5 s for keys of whole types and 12.6 s for spelled keys, measured with
scratchpad mutants). Value references and references inside lambdas are
call-graph edges (design §6); constructors, called or bare, are not.

### The specialization limit

`specializationLimit = 10000`, global. It counts only keys created from
polymorphic declarations: each instantiation of a function that has type
variables and each ground application of a type that has parameters,
together. Monomorphic functions and types (the seeds) never count, so
existing large monomorphic programs are unaffected. The reference that
would create key 10,001 is E_SPECIALIZATION `More than 10000
specializations`; a key found inside a constructor field is reported at
that nested reference. The limit is a resource guard, never the
termination argument (§4.2 is). Evidence: test/poly-run.test.mjs (6,000
function plus 4,000 type keys compile; one more of either fails at its
reference).

Deviation from spec §6 (ruling R18): for a key first created in a function
signature, the span is the whole function declaration, because the checked
IR keeps no signature syntax. Only a never-called monomorphic seed whose
signature creates key 10,001 is affected; threading signature TypeRefs
through the checked IR would fix it.

## Consequences

- Generic code costs one Go copy per key; output size grows with the
  number of distinct instantiations (3,000 instantiations compile in about
  0.6 s, test/large-source.test.mjs).
- Argument-doubling type chains and nested `dup` calls give exponentially
  large (but finite) types (R14, BACKLOG E007).
- Coverage's Expand keys are whole types, quadratic along growing chains;
  hash-consing them like Specialize's keys is a follow-up (BACKLOG).
- C001 attaches evidence to the recorded instantiations; it must report a
  constrained hole as ambiguous rather than use the representative.
