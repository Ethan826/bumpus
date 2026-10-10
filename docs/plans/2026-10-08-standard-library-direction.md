# Standard-library direction and helper coverage (STD001)

Recorded 2026-10-08 at the user's request. Status: requirements and naming
direction, not an implementation plan. Build the common FP helpers found
in PureScript and Haskell, with approachable names informed by Rust and
other familiar APIs. This adds no implementation work to FN001.

## Naming and discoverability

Prefer names describing the operation over historical abbreviations,
punctuation variants, jokes or terminology users must research. Do not
require names such as Clown/Joker or intercalate to discover ordinary
operations. Preserve useful abstractions without inheriting every name.
Conventional names such as map, filter and flatMap remain good candidates.
Document familiar upstream equivalents as a migration index, not a second
mandatory API vocabulary. Names below are candidates, not frozen APIs.

Use FN001's data-last, curried, pipe-friendly direction consistently.
Coordinate module organization and namespace collisions with M001, and
overloaded/generic helpers and instance selection with K001/C001. Ordinary
specialized helpers should not all wait for the generic class machinery.
Public Waxwing names do not rename the compiler's PureScript APIs or relax
its current maybe/either source-style conventions.

## Generic abstractions and theoretical rigor

User clarification 2026-10-08: approachable names must preserve the
theoretical structure, not replace it with unrelated per-type convenience
APIs. Rust informs discoverability; PureScript/Haskell inform the lawful
generic interfaces. Retain meaningful canonical names such as Bifunctor
and bimap, explaining them with examples rather than avoiding the concept.

The following are semantic contracts, not approved constraint syntax:

```text
map: forall f, a, b. Functor(f) =>
  (a -> b) -> f(a) -> f(b)
flatMap: forall m, a, b. Monad(m) =>
  (a -> m(b)) -> m(a) -> m(b)
bimap: forall p, a, b, c, d. Bifunctor(p) =>
  (a -> b) -> (c -> d) -> p(a, c) -> p(b, d)
```

bimap must work for any lawful user-defined Bifunctor, including product
and sum examples, not just Result's error/success branches. A friendly
mapBoth name, if provided, must expose the same generic operation/evidence
rather than a Result-only substitute. Result-specific mapError can remain
a convenience derived from the corresponding bifunctor operation.

Optional values and Result with a fixed error type should share generic
Functor/Applicative/Monad operations. Result as a two-argument constructor
also admits Bifunctor; Option is unary, not a Bifunctor merely because it
has two constructors. K001 must support the required constructor kinds and
partial type application; C001 must specify lawful instance/evidence
selection and coherence among shared operations. Their designs must
resolve how generic operations are represented under the rank-1 scope and
specialization, rather than silently requiring polymorphic record fields.

Require generic client examples over unknown constructors and lawful
user-defined instances. Property tests must cover functor identity and
composition, bifunctor identity and composition, applicative laws, monad
identities/associativity, and consistency of related operations (such as
map versus pure/flatMap). Choose observation/equality appropriate to each
instance, document lawful domains, and distinguish pure callbacks used in
algebraic laws from effectful callback sequencing designed by FX001.
An error-accumulating validation applicative must not be given a monad
instance with incompatible application behavior merely to share names.

Early concrete helpers after FN001 are an incremental delivery, not the
finished generic library. STD001's generic acceptance remains open until
K001/C001 permit the shared contracts and user-defined-instance tests.

## Coverage inventory to turn into designs

- Optional values: presence tests, defaults, branch elimination, map,
  flatMap, filter, flatten, alternatives, zip/combine, conversion to a
  typed result, collection of present values and transpose.
- Results: success/error tests, defaults and recovery, two-branch
  elimination, success/error/both-side mapping, flatMap, flatten,
  alternatives, combination, conversion to optional values, transpose,
  and inspection. Support composed/open error channels when that design
  lands; do not force application-wide error wrappers.
- Functions and pairs: identity, constant, composition in both directions,
  argument reordering where useful, pair construction/projections, and
  independent transformations of both components. Review common
  higher-order adapters on their purpose rather than whimsical names.
- Sequences: map, filter, filterMap, flatMap, flatten, append, folds and
  scans with direction made explicit; first/last/index lookup, find,
  any/all/count, take/drop and conditional forms, split, partition,
  chunking, grouping, sorting, deduplication, reverse, zip/zipWith/unzip,
  generation/unfolding and empty/non-empty handling.
- Text: joining with separators, inserting separators, splitting,
  trimming, prefix/suffix/search, safe parsing and rendering. Coordinate
  encoding, indexing and Unicode semantics with D001 rather than assuming
  byte, code-point and user-visible character operations coincide.
- Maps and sets: lookup, membership, insertion/removal returning new
  values, update, merge/union/intersection/difference, transformations and
  deterministic iteration policies. Preserve explicitly selected
  comparison/instance identity where the C001 design requires it.
- Generic FP operations: mapping, combining wrapped values, flattening and
  chaining, folds, collecting wrapped results and mapping then collecting
  them (sequence/traverse equivalents). Coordinate laws and generic
  signatures with K001/C001; explain sequencing, order and error behavior.

Audit the upstream common APIs against this inventory before declaring
coverage complete. Every common operation must have a proposed Waxwing
equivalent or a documented reason/dependency for deferral. This is broad
coverage, not a promise to clone all packages or every specialized API.

## Candidate names and distinctions

| Operation | Candidate Waxwing name | Familiar equivalent |
|---|---|---|
| Extract a value or use a supplied default | getOrDefault | fromMaybe; Rust unwrap_or |
| Extract a value or compute a fallback only when needed | getOrElse | fromMaybe'; Rust unwrap_or_else |
| Transform a present value, otherwise use a supplied default | mapOrDefault | maybe; Rust map_or |
| Transform a present value, otherwise compute a fallback | mapOrElse | maybe'; Rust map_or_else |
| Eliminate either branch into one result type | matchWith | either |
| Transform successful values, preserving errors | map | fmap/map |
| Transform only the error value | mapError | Rust map_err |
| Transform both covariant type parameters of any Bifunctor | bimap (optional alias mapBoth) | bimap |
| Chain an operation returning another wrapped value | flatMap | bind; Rust and_then |
| Remove one layer of wrapping | flatten | join |
| Convert an optional value to a typed result | toResult / toResultElse | note/note'; Rust ok_or/ok_or_else |
| Join sequences or text with a separator | joinWith | intercalate |
| Insert separator elements without flattening | insertBetween | intersperse |
| Collect wrapped values into a wrapped collection | collect | sequence |
| Map to wrapped values, then collect | mapAndCollect | traverse |

getOrElse alone does not replace every maybe/either use: a branch
eliminator may change the result type, whereas extracting a value with a
default has a narrower purpose. Distinguish error mapping from error
recovery and from inspecting an error. Do not use a friendly name to
collapse different semantics into one ambiguous helper.

## Delivery and acceptance

After FN001, design and deliver optional/result/function/list helpers
that its type system already supports. Coordinate later text/numeric/map
and set APIs with D001, exports with M001, generic operations with
K001/C001, and effectful callbacks with FX001. Split implementation into
focused reviewed plans; keep current slices and snapshots unchanged.

Require usage examples readable without upstream terminology, the coverage
matrix, explicit signatures and evaluation rules, and focused behavioral
tests. Prove computed fallbacks and unselected callbacks are not executed;
pin callback order, short-circuit versus accumulated errors, empty inputs,
error preservation and collection complexity. Use law/property tests when
the operation has domain-wide laws. Default to total helpers returning an
optional/result for missing data; do not inherit partial head/unwrap
operations as the normal API. Inspection helpers must declare any effects.
No concurrency follows automatically from collection or traversal names.

## Primary references

- [Rust Option](https://doc.rust-lang.org/std/option/enum.Option.html).
- [Rust Result](https://doc.rust-lang.org/std/result/enum.Result.html).
- [PureScript Maybe](https://github.com/purescript/purescript-maybe/blob/master/src/Data/Maybe.purs).
- [PureScript Either](https://pursuit.purescript.org/packages/purescript-either/6.1.0/docs/Data.Either).
- [Haskell List](https://hackage.haskell.org/package/base/docs/Data-List.html).
- [PureScript Bifunctor](https://pursuit.purescript.org/packages/purescript-bifunctors/6.0.0/docs/Data.Bifunctor).

These are conceptual/API references. No implementation is copied.
