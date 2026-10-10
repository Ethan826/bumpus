# First-party schemas, boundary parsing and generated test data

Recorded 2026-10-10 at the user's request. SCH001 is a requested language/
standard-library foundation for the v1 planning discussion, not an approved
implementation plan. The user wants a built-in Schema facility connecting
boundary parsing and property tests: "parse don't validate" is a requirement.
Compare Effect Schema and the supplied rae-hill/schemata-ts repository.
Do not expand the active FX008 work.

## Contract: parse into trusted domain values

Successful boundary parsing constructs a value whose type preserves the
established invariants. Returning a Boolean and continuing with unchecked
input is not the primary API. Expected malformed input produces structured,
typed errors. Business/domain functions consume the parsed type rather than
repeat the boundary checks. Predicate checks can be implementation details;
the public contract carries their result in a domain value.

Illustrative pseudocode, not selected Waxwing syntax:

```text
parse : Codec(Input, Domain) -> Input -> Either ParseError Domain
encode : Codec(Input, Domain) -> Domain -> Either EncodeError Input
arbitrary : Schema(Domain) -> Generator Domain
```

Raw JSON, bytes, text, environment/configuration data and foreign values need
explicit boundary representations. Parsing a JSON object is not an unsafe
cast to a domain record. Separate wire and domain types, and distinguish
missing fields, nulls, defaults and unknown-field policies.

Opaque types/smart constructors should prevent ordinary callers from
manufacturing invalid domain values. Nominal wrappers or other refinement
mechanisms remain design choices; explicit instance selection's no-mandatory-
newtype direction does not eliminate the need for domain invariants.

## Comparison and conceptual influence

Effect's v4 documentation distinguishes decoded and encoded representations
and services needed for decoding/encoding. It supports transformations,
structured issues, arbitrary generation/shrinking and other interpretations.
This is useful for separating pure parsing from parsing that requires an
explicit service. Do not silently mix v3's Schema API with v4's Codec API.

Schemata-ts describes schemas through a Schemable capability interface,
with interpreters including Transcoder, Arbitrary and JSON Schema.
Transcoders have separate input/output types and decode unknown values into
Either with structured errors. Its explicit interpreter approach connects
particularly well to C001/R001's selectable dictionaries and M001's
abstraction boundaries. These are conceptual comparisons, not a decision to
adopt its TypeScript representation or advanced typing requirements.

## Capability overlap, precedents and representation

The follow-up comparison found substantial overlap with current Effect:
parsing/encoding, transformations, generated test data, JSON Schema and
schema-derived equality. No major missing Effect capability needed by
SCH001 was established. Schemata advertises customizable schema-derived
merge semigroups; an equivalent built-in Effect API was not established.
That is a candidate convenience to examine, not a verified exclusivity claim
or a reason to infer algebraic laws for arbitrary merging policies.

The principal distinction is representation, approximately:

```text
Schemable encoding: schema + selected interpreter -> derived operation
Syntax-tree encoding: schema AST -> interpreter -> derived operation
```

Schemata makes the selected interpreter explicit through Schemable. Effect
exposes a concrete SchemaAST and interpreter customization, including
annotations for generating opaque types. Multiple interpretations and
extensibility are therefore not exclusive to Schemata.

There are independent precedents at different levels:

- io-ts supplies the direct Schema/Schemable precedent: its Schema accepts
  a Schemable interpreter. Those APIs are explicitly experimental; do not
  confuse the maturity of the general idea with that API's stability.
- Tagless-final programming is the broader established family: express a
  typed description through an interface and supply different interpreters.
  Schemata's interpreter-parametric design belongs to that family; no claim
  is made that all its implementations inherit formal soundness results.
- ZIO Schema corroborates one description supporting multiple operations,
  including codecs and diffing, through a reified schema representation.
  This supports the goal, not the exact Schemable encoding.

Recommendation: adopt the requirement for multiple useful interpretations;
keep representation open. Explicit interpreters fit selectable dictionaries.
An AST can make inspection, export, diagnostics and compiler derivation more
direct. Neither encoding is established as superior here. Compare both on
one boundary codec, one constrained generator/shrinker and one additional
user-defined interpretation, including the typing/prerequisite cost.

## Proposed architecture and open choices

Provide one composable description with supported interpretations for
boundary parsing, optional encoding, valid-data generation and shrinking.
Assess a schema syntax tree versus a Schemable/dictionary encoding, including
extensibility, diagnostics, specialization and target portability. An
interpreter-parametric encoding may need polymorphism beyond the initial
rank-1 core; state the prerequisites rather than assuming them away.

"Built-in" means first-party and supported. Decide how much is ordinary
library code and whether compiler-assisted derivation is needed. Do not
require special syntax, runtime reflection or a second type checker without
a demonstrated benefit. Compare deriving structural schemas from declared
ADTs/records with explicitly authored wire formats and semantic constraints.
Avoid duplicating structural declarations, while allowing several codecs
for the same domain type and explicit selection/composition of interpreters.

Parsing/encoding should be pure when possible. External lookups, asynchronous
checks and service requirements must appear in ordinary effect types. Such
checks establish a fact at parsing time, not a timeless guarantee about
mutable external state. Define failure accumulation versus fail-fast behavior,
path-aware diagnostics, recursive-input limits, and resource bounds.

## Property testing: generate data, not arbitrary truths

Derive valid-domain generators and invariant-preserving shrinkers for the
supported schema subset, with seeds/replay and useful boundary distributions.
A schema cannot infer arbitrary business properties. Properties, expected
results and useful coverage requirements remain independently specified.

Arbitrary predicates or one-way transformations need explicit generation/
shrinking support or a clear unsupported-derivation error. Do not rely on
unbounded filtering, assume an inverse exists, or silently generate no cases.
Test-only generator machinery should not be bundled into production programs
that use only the parsing interpretation.

State laws per codec: lossless codecs may satisfy decode(encode(a)) ≈ a;
normalizing codecs need a specified canonicalization/equivalence relation.
Encoding may be partial or unavailable. Do not promise a universal two-sided
round trip for lossy transforms. Schema-derived equality is also a selectable
policy and must not silently override domain equality.

Include independently constructed malformed inputs and boundary cases;
generating valid values and round-tripping through a parser/encoder derived
from the same schema can miss shared defects. Require known-defect sensitivity,
non-vacuous coverage, discard statistics and meaningful shrinking.

## Placement and proposed acceptance

Coordinate SCH001 with D001 (text/numbers/collections), R001/C001/K001
(records/evidence/kinds), M001 (opaque domain types and exports), I001
(foreign ingress), STD001, PBT001 and PKG001. Record a coherent v1 subset and
sequence in its own reviewed design; no implementation is authorized here.

Acceptance examples should cover:
- Parse external configuration or a request into an opaque domain ADT.
- Reject invalid data with field/index paths and bounded diagnostics.
- Map an encoded string to a constrained numeric domain value.
- Select two wire codecs for one domain type explicitly.
- Generate valid domain values and shrink without breaking invariants.
- Detect a deliberately broken parser and a broken independent property.
- Replay a counterexample and reject unsupported generator derivation.
- State round-trip laws for both lossless and normalizing codecs.

## Sources and scope of inspection

Primary documentation/README consulted 2026-10-10, not source implementation
or a complete library audit. Pin repository revisions and API versions in
LA001/SCH001's focused design. No external code copied.

- [Effect v4 introduction](https://effect.website/docs/v4/schema/introduction).
- [Effect v4 transformations](https://effect.website/docs/v4/schema/transformations).
- [schemata-ts supplied repository](https://github.com/rae-hill/schemata-ts).
- [schemata-ts Schema interface](https://schemata.jacob-alford.dev/schema/),
  linked documentation under its historical project domain.
- [Effect SchemaAST](https://effect.website/docs/v4/api/effect/SchemaAST)
  and [interpreter customization](https://effect.website/docs/v4/schema/advanced-usage).
- [io-ts Schema](https://gcanti.github.io/io-ts/modules/Schema.ts.html)
  and [Schemable](https://gcanti.github.io/io-ts/modules/Schemable.ts.html).
- [Kiselyov's tagless-final research overview](https://www.okmij.org/ftp/tagless-final/index.html).
- [ZIO Schema](https://zio.dev/zio-schema/).
