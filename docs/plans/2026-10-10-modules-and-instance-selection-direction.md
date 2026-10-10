# Modules and explicit instance selection: direction

Recorded 2026-10-10 at the user's request. Status: user preferences,
assistant recommendations, and open design questions; not an approved
specification or implementation plan. Coordinate C001, R001, M001,
K001, STD001, PKG001 and the concurrency foundations. Do not interrupt
FX008 or expand the active implementation milestone.

## User preferences and scope

The user values Rust and PureScript modules and TypeScript's ESM experience.
They also want fp-ts-style selection and construction of specific instances,
such as a last-value semigroup, without requiring a newtype. This extends
C001's existing multiple-instance direction. Recording it does not select
module syntax, class syntax, implicit resolution, or a runtime representation.

## Module responsibilities

Evaluate namespace/import organization, encapsulation, implementation
composition, and package/build integration separately. Compare:

- PureScript: explicit exports, selective constructor exposure, qualified
  imports and re-exports; type classes supply a separate abstraction layer.
- Rust: private-by-default items, scoped visibility, and public re-exports
  that separate API paths from internal layout; traits/generics supply much
  of the implementation composition.
- Standard ML/OCaml: signatures, abstract types, type-sharing constraints
  and parameterized modules (functors). These package types with operations
  and express relationships between separately supplied components.
- TypeScript/ESM: familiar imports/exports and interoperability, while
  resolution and execution depend on host and package/tool configuration.

Assistant recommendation for M001: clear explicit imports/exports,
enforced package-internal boundaries, abstract types, and predictable
resolution. Evaluate imports with no hidden runtime initialization; resource
acquisition and service startup would then be explicit effectful operations.
Choose type/package identity and abstraction rules before polishing import
spelling. Stable binary separate compilation remains deferred as recorded
in M001; interface checking is a distinct concern.

Do not add ML functors automatically. First compare what functions, records,
classes, and effect handlers already express. Parameterized modules are
valuable where they establish relationships between abstract types; avoid
parallel mechanisms with overlapping responsibilities.

## Instances as selectable and constructible values

An explicit instance is conceptually a dictionary of operations. Illustrative
pseudocode, not approved Waxwing syntax:

```text
combineAll(sum, numbers)
combineAll(product, numbers)
combineAll(last, numbers)
recordSemigroup({ count: sum, latest: last })
```

The same data type can support several implementations. Functions can
construct or combine dictionaries, including selecting an instance per
record field. No wrapper type is needed solely to choose behavior. Newtypes
remain useful for actual domain distinctions and invariants.

Distinguish providing operations from selecting an implementation. Compare
explicit evidence with optional implicit defaults; any implicit selection
must have predictable ambiguity, overlap, scope and termination rules.
Assistant recommendation: make explicit named evidence a supported
foundation, and assess implicit convenience separately. Ordinary record
representation versus dedicated class evidence remains a C001/R001 decision.

## Coherence, ownership and instance identity

Rust's orphan rules restrict trait implementations, roughly requiring a
local trait or implementing type, with additional generic coverage rules.
Haskell permits orphan instances; GHC can warn about them. Do not describe
Haskell as imposing Rust's ownership prohibition. These systems address
implicit resolution and coherence; explicitly passed dictionaries avoid
that selection ambiguity but do not remove all consistency obligations.

A sorted set built with one ordering must not be searched or merged using
an incompatible ordering. Assess retaining the dictionary, type-level
identity/witnesses, or abstract module types. Retention alone does not make
merging collections with different policies safe. Define compatibility and
cross-module behavior without assuming pointer identity or newtypes are
mandatory. Coordinate these decisions with map/set APIs and specialization.

Laws are separate from dictionary shape. Providing a Semigroup operation
does not prove associativity; providing Ord operations does not prove their
ordering laws. Distinguish compiler-established guarantees, trusted built-ins,
user obligations and property-test evidence. If parallel reduction or another
optimization relies on a law, specify exactly what justifies the rewrite,
including effect order and observable failures. Modules/classes alone do not
prove laws, race freedom, or deterministic execution.

## Design acceptance scenarios and open decisions

Before implementation plans, specify examples that demonstrate:

- Selecting sum, product and last for the same type without wrappers.
- Constructing record instances from independently selected field instances.
- Writing a generic client against explicitly supplied evidence.
- Exporting an abstract type and operations while hiding representation.
- Re-exporting a stable API independently of private source layout.
- Two packages publishing alternatives without implicit-selection conflicts.
- Safe collection lookup and explicit rejection or conversion for incompatible
  collection merges, including across modules.
- Useful ambiguity diagnostics if implicit defaults are supported.

Resolve dictionary representation/selection jointly in C001/R001, module
and type identity in M001/PKG001, and laws in STD001/concurrency planning.
No syntax, functor system, global-instance policy or law-proof mechanism is
approved by this note.

## Primary sources and conceptual provenance

Sources consulted for the discussion; no implementation code copied:

- [fp-ts Semigroup](https://gcanti.github.io/fp-ts/modules/Semigroup.ts.html):
  explicit instances and instance constructors.
- [PureScript modules](https://github.com/purescript/documentation/blob/master/language/Modules.md).
- [Rust visibility](https://doc.rust-lang.org/reference/visibility-and-privacy.html)
  and [coherence](https://doc.rust-lang.org/reference/items/implementations.html#trait-implementation-coherence).
- [OCaml modules](https://ocaml.org/docs/modules): signatures, abstract types
  and functors; conceptual ML comparison.
- [TypeScript module theory](https://www.typescriptlang.org/docs/handbook/modules/theory.html).
- [GHC orphan warnings](https://downloads.haskell.org/~ghc/8.6.3/docs/html/users_guide/using-warnings.html):
  versioned documentation supporting the ownership-rule distinction.
