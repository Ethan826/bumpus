# ADR 002: planned specialization plus explicit evidence

Accepted as architecture direction, not implemented, 2026-10-07.

Begin with rank-1 type schemes, mandatory top-level signatures, first-order
unification with occurs checks, and kinds built from Type, Row, and arrows.
An HKT is a constructor with a known arrow kind; matching constructor
applications is not arbitrary higher-order unification. No type-level
lambdas, GADTs, families, dependent types, or polymorphic recursion initially.
Reject recursive calls at differing type instantiations to keep specialization
finite. Higher-rank inference and sophisticated deriving remain deferred.
Jones's executable account separates kinds, substitutions, unification, and
class predicates; it is a useful semantic reference, not imported code:
https://web.cecs.pdx.edu/~mpj/thih/TypingHaskellInHaskell.html

Use whole-program reachable specialization for polymorphic/HKT code. Each
concrete type/constructor application gets a deterministic specialization key.
This gives ordinary Go functions/structs and avoids pretending Go generics
implement our language's constructor-kinded variables. Memoize specializations,
track recursive keys, set an explicit growth budget, and diagnose expanding
instantiation. Generated code growth is a real cost; optimize after measuring.
Initially modules expose checked interfaces, but final executable generation
needs transitive typed bodies. Stable binary separate compilation is deferred.

Classes elaborate to explicit dictionaries. Require non-overlapping instances,
unique ownership/orphan restrictions, terminating resolution, and deterministic
evidence before specializing dictionaries. Ambiguity is an error. No runtime
search. Source dictionary operations and inferred constraints must be explicit
in elaborated IR; do not use Go method sets as a substitute for coherence.

Rows describe records first; extensible variants are a later phase. Use unique
labels with lacks constraints, rejecting duplicate labels. This deliberately
differs from scoped-label shadowing. Normalize label order and specialize open
row functions to concrete record layouts; carry accessor evidence when needed
in the elaborated IR. This combines specialization and explicit evidence without
requiring a dynamic map for every record. A uniform boxed fallback is reserved
for future separate compilation; do not implement unchecked any assertions now.
Relevant primary research and the alternative scoped-label tradeoff:
https://www.microsoft.com/en-us/research/publication/extensible-records-with-scoped-labels/

Boxing may eventually support existential packages and separately compiled
polymorphic interfaces. Every box requires explicit type evidence, validated
FFI construction, and checked projections. Nil is not an implicit source value.
Representation changes require an ABI/version decision and fresh bootstrap
comparisons. This strategy can be revised by an ADR before implementation.
