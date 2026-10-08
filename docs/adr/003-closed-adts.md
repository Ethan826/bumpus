# ADR 003: closed ADTs, one tagged struct per type

Accepted and implemented 2026-10-07 (milestone A001). Binding spec:
docs/plans/2026-10-07-closed-adts-design.md including its section 10
amendments. Verification is named per decision; everything not named there is
proposed, not verified.

## Decisions

1. **Representation A.** Each declared type is one Go struct carrying a
   `uint32` tag and one field per constructor field, named `c<CtorId>f<i>`.
   Primitive fields are stored directly; ADT fields are pointers to a copy.
   Constructors are Go functions; values are never mutated. Tag 0 is never
   produced. Checked by `Go declarations use the pinned bytes`
   (test/adt-types.test.mjs) and the snapshot `bootstrap/shapes.go`
   (`shapes example matches its snapshot and runs`, test/adt-match.test.mjs).
   Rejected: one struct per constructor behind an interface (needs Go method
   sets or type switches, which ADR 002 declines to treat as coherence).
2. **Nil-guard safety policy.** Every pointer projection is preceded by a
   `!= nil` test earlier in the same `&&` chain, so generated code never makes
   an unguarded nil dereference. A malformed value (tag 0, tag past the owner,
   nil field under a valid tag) reaches `panic("bumpus: unmatched value")` only
   if a match inspects the malformed part. **Limit:** wildcards and binders do
   not validate what they skip; `malformed values reach the unmatched panic,
   never a nil error` and `wildcards skip validation of a nil field`
   (test/adt-match.test.mjs) pin both sides. Values built in source are
   well-formed, so the panic is unreachable in an accepted program. Deep
   validation of foreign values belongs to I001. The `nil-guard` regression
   row (scripts/regression.mjs) fails when the guard is dropped.
3. **Uppercase rule.** Type and constructor names start with A-Z; in a pattern
   an uppercase name is always a constructor and a lowercase name a binder, so
   a misspelled constructor cannot become a catch-all (`type t = A;` is
   E_SYNTAX, test/diagnostics.test.mjs).
4. **Reserved words.** `type`, `match` and the lone `_` are reserved. This
   breaks Stage 0 programs that used them as identifiers; no test program did.
   Consequence: `fn main(): Float = 1;` moves from E_SYNTAX to E_UNBOUND
   (`Float` is now an unknown type name, not a bad token); the Float row in
   test/compiler.test.mjs was updated and is the only changed Stage 0 row
   besides the property test's parse accessor.
5. **CtorId versus tag.** The checked IR names a constructor by `CtorId`
   (global, declaration order). The Go tag (1-based index within the owner)
   exists only in lowering, so the IR says nothing about representation.
6. **Lifted match functions (E005; superseded depth naming).** Each match
   lowers to a top-level Go function, not an immediately invoked closure,
   because Go's inliner expands nested closures exponentially (24 nested
   matches took 34.6 s and 7.5 GB to build; 128 were killed). The k-th match
   of `bumpusFn{f}`, numbered from 0 in one pre-order walk of the body that
   visits a match's scrutinee before its arms, is `bumpusFn{f}Match{k}`; a
   counter is threaded through expression lowering (Format.Go.Lowered). Its
   parameters are the locals its arms capture, ascending by LocalId and named
   `bumpusLocal{id}` with their IR types, then `bumpusScrutinee`; the call
   site passes the same locals, then the scrutinee expression, so the
   scrutinee is still evaluated once at the same point. Capture analysis
   (Format.Go.Capture) reads the whole of every arm, nested scrutinees and
   nested arms included, minus every binder introduced inside the match
   (LocalIds are unique per function); only the match's own scrutinee is
   excluded. Lifted functions follow their `bumpusFn{f}` in number order,
   each preceded by a blank line. `if` keeps its closure. Checked by
   test/match-lift.test.mjs (exact signatures and order; captures through
   nested matches), test/depth.test.mjs (match-arm and compare-matches at the
   nesting limit; 128 nested matches build and run in under 10 s) and the
   `capture` regression row.
7. **E_DUPLICATE at the first occurrence**, the Stage 0 rule, applied to
   types, global names (functions and constructors share one table),
   parameters and binders (test/diagnostics.test.mjs). For a
   function/constructor clash the first occurrence is by source position,
   whatever its kind (test/adt-types.test.mjs).
8. **Decision trees deferred.** Lowering is sequential first-match: arm
   conditions in order. This is simple to verify against the first-match
   interpreter (`generated match programs agree with a first-match
   interpreter`, test/adt-properties.test.mjs) and costs repeated tag tests.
   Compilation to decision trees is a Planned BACKLOG row (A002); it is also
   what would give a target-neutral `Features.Lower` real work (ADR 004).
9. **Uninhabited types are legal.** `type T = C(T);` is accepted. Coverage
   computes inhabitedness as a least fixed point; an arm naming an
   uninhabited constructor is not required, and a wildcard whose remaining
   constructors are all uninhabited is E_REDUNDANT, never offered as a
   witness (`uninhabited constructors need no arm` and `a wildcard over only
   uninhabited constructors is redundant`, test/adt-coverage.test.mjs).
   Coverage is also checked independently by test/coverage.test.mjs, a
   brute-force enumeration oracle that does not use Maranget's algorithm,
   and against brute-forced inhabitedness over generated small type systems
   (`constructor coverage agrees with brute-forced inhabitedness`). An
   invalid TypeId, or a constructor field count that disagrees with the
   tables, is E_INTERNAL, not a pass (test/diagnostics.test.mjs).

## Consequences

ADT values have no printing, equality or ordering (`main` returns Int or
Bool). Type parameters, records, guards, or-patterns and empty matches are out
of scope (`match x {}` is E_SYNTAX).
