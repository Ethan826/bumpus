# Developer tooling and executable documentation direction

Recorded 2026-10-08 from the user's requested feature directions.
Status: planning requirements, not implementation designs or authorization.
Keep FN001's approved delivery fixed. Each subsystem needs a focused design,
acceptance criteria and implementation plan; no syntax or tool is selected.

## IDE001: Syntax highlighting and IDE support

Syntax highlighting and editor support are product requirements, not
optional polish. Stage lightweight highlighting separately from semantic
IDE services; do not require one editor to use the language.

Proposed progression: highlighting, compiler diagnostics in the editor,
then hover/type information, completion, definition navigation and rename.
Evaluate a language server and editor adapters in the design. Reuse the
compiler's language rules and source locations; recovery for incomplete
programs must not introduce a second authoritative grammar/type system.
Coordinate symbol identities and cross-file operations with M001.

Proposed acceptance: real files and incomplete edits retain useful feedback;
diagnostics agree with the CLI, references resolve across modules, and
rename preserves binding identity. Pin responsiveness and large-file limits
after measurement. Decide formatter and semantic-highlighting scope explicitly.

## DOC001: First-class doctests

Examples in documentation should be executable, checked language artifacts,
with a standard way to discover and run them in local development and CI.
Support documenting values, behavior and intended diagnostics, rather than
only comparing printed text. Syntax, placement and runner commands remain
design decisions; module/API docs and standalone guides need one model.

Use the ordinary compiler and test runner. Preserve original document
locations in failures. Decide example scope, imports, hidden setup, output
comparison, expected compilation failure and time limits. Coordinate effect
examples with FX001 so clock/random/database behavior uses explicit fakes
and reproducible inputs rather than live services.

Proposed acceptance: a changed documented result and a changed expected
diagnostic both fail; examples are discoverable, attributable to their
source, and exercised by the normal verification workflow. This is a
language-user feature, distinct from today's compiler test suite.

## PBT001: Property-based testing for Waxwing programs

Provide supported generators, combinators, shrinking, reproducible seeds
and replay, useful minimal-counterexample reports, and ordinary test-runner
integration. Merely running randomized examples is not sufficient.

Coordinate with FN001, D001, STD001 and K001/C001 for generators of
user-defined ADTs and generic algebraic-law suites. Properties must assert
independent contracts, including Functor/Applicative/Monad/Bifunctor laws
and coherence where applicable. Decide generator derivation and whether
generic law helpers arrive incrementally; neither mechanism is selected.

Proposed acceptance: deliberately broken implementations are detected,
counterexamples shrink while preserving generator constraints, and a saved
seed/case replays. Cover boundaries and monitor distribution/discard rates
to avoid vacuous success. Test effectful programs using controlled runtimes;
future backend equivalence tests must state their common semantics.
Existing host-side compiler properties do not satisfy this language-library
milestone by themselves.

## LIT001: Literate capabilities (exploratory)

Explore writing explanations and checked Waxwing code together. The user's
"maybe" remains an open adoption decision. Compare executable Markdown
fences using DOC001 with a dedicated literate source mode; do not assume
new file extensions, tangling, notebooks or embedded evaluation are needed.

Assess source maps, module identity/imports, code-block order, scope,
documentation generation and editor support. A useful minimum would let
one artifact explain a program while CI checks its code. If extraction is
chosen, derived files must have an explicit source of truth and drift check.
Proposed acceptance: errors point to the authored document, extracted code
has defined equivalence to ordinary source, and IDE/doctest workflows agree.

## AI001: LLM skills and discoverability

Make authoritative, versioned language and tooling guidance easy for both
people and coding agents to find. Provide a clear documentation entry point,
searchable API/reference material and concise worked examples. Evaluate
task-oriented skills for writing, checking and debugging Waxwing, with
explicit tool commands, supported versions, limitations and source links.

Favor information generated or checked against compiler/library metadata
over a parallel handwritten specification. Evaluate machine-readable API
and diagnostic contracts, symbol discovery and searchable documentation;
no particular manifest, protocol, hosted service or agent vendor is chosen.
Skills are workflow aids, not the authority for language semantics.

Proposed acceptance: documentation-only consumers can find the current
syntax, locate an API, run an example and interpret a diagnostic. Check
skill examples as DOC001 artifacts where possible; stale commands or
unsupported syntax must be detectable. Agent evaluation should record
model/tool versions and failures, not promise universal LLM correctness.

## PKG001: Libraries, host integration and package management

The user requires an ecosystem that distinguishes three composable roles:

| Role | Responsibility | Proposed example |
|---|---|---|
| Waxwing library | Waxwing source compiled with the application to its selected target; portable when its dependencies and semantics are portable | Domain validation, collection operations, shared application logic |
| FFI binding | Typed access to a specific host library/API, with explicit conversion and foreign-value validation | A Go logger or AWS SDK binding |
| Service implementation | Fulfill a Waxwing-owned capability contract using a binding, Waxwing code or a test fake | Logging or object storage implemented by a chosen host library |

These are roles, not mandatory package kinds: a package may contain several,
and an adapter may use FFI internally. A dependency-inverted application
depends on the service contract; application assembly chooses its concrete
implementation. Direct FFI remains available when host-specific APIs are
the intended dependency. Avoid forcing every foreign function through a
service abstraction or flattening every AWS service into a universal API.

Effect's [Platform introduction](https://effect.website/docs/v4/platform/introduction)
is a conceptual precedent: abstract services are fulfilled by implementations
selected for the runtime. Review its versioned sources in LA001; this is
not adoption of Effect's specific layer, context or runtime mechanisms.
For Waxwing, service records versus effect handlers remains C001/R001/FX001
design work. Separate compilation targets from runtime availability: one
target can have several hosts, and a host may lack a required capability.

Design library consumption in both directions. Waxwing applications should
consume Waxwing source and typed host bindings. Also assess whether compiled
Waxwing libraries can expose usable APIs to host-language callers, including
export names, generic instantiation, data/function representation, errors,
effect execution and required runtime support. This does not select a stable
binary ABI or change M001's separate-compilation deferral.

Package management must describe and resolve the combined dependency graph:
Waxwing modules/packages, service contracts/implementations and host packages.
Evaluate a manifest and lockfile with compiler/language compatibility,
target/runtime support, package versions, source identity and selected
host-dependency versions. Prefer integrating Go's dependency tooling for Go
libraries, and evaluate the corresponding ecosystem tooling for later
targets, rather than independently reimplementing their resolvers.

Define who owns generated host manifests and how applications reconcile
host constraints from multiple Waxwing dependencies. Decide version conflict
rules, transitive resolution, duplicate package/type identity, adapter versus
contract compatibility, workspace/path dependencies and reproducible cached
builds. Give unsupported target/runtime combinations and missing providers
clear diagnostics. Evaluate package discovery, documentation, examples,
publication/distribution and provenance separately; recording these needs
does not authorize publishing packages or choosing a registry.

Pure/shared application code should not import a concrete SDK merely to use
its capability. FFI adapters must define foreign errors versus defects,
resource lifetime and any async/cancellation mapping in coordination with
I001/FX001. Implementations claiming the same service contract need shared
conformance tests; availability and operational differences must be explicit.

Proposed acceptance scenarios:

- Compile a Waxwing library into a Go application and verify its host-facing
  API if library export support is chosen. Later targets require their own
  equivalent proof before portability is claimed.
- Run one application against a fake logger/storage provider and a real
  host-library adapter without changing its domain logic. Test malformed
  foreign values, typed failures and provider contract behavior.
- Resolve an application with multiple Waxwing packages and shared host
  dependencies; reproduce the build from the lockfile in a fresh workspace
  and from a prepared offline cache. Diagnose conflicts and unsupported
  capabilities, and deliberately change an adapter/contract version to test
  compatibility checks.

PKG001 coordinates M001 (module identity/linking), I001 (FFI), C001/R001
and FX001 (contracts/provision), STD001 (library surface), J001 (future
targets), and DOC001/AI001/IDE001 (package documentation and discovery).
Source packages must fit whole-program specialization; no pre-specialized
binary package format or runtime provider-discovery mechanism is selected.

## Audit, dependencies and sequencing

LA001 must examine executable documentation, property testing, editor
feedback, literate workflows and agent discovery alongside language
features, plus PKG001's library/binding/provider roles and dependency graph.
Separate built-in features from library/ecosystem tooling in the
source briefs and decision matrix. Absence in a reference is not a reason
to omit a user requirement.

Begin discovery guidance and basic highlighting early; semantic IDE work
depends on stable compiler services and M001. DOC001 and PBT001 should
inform documentation/library design before those interfaces settle.
LIT001 remains exploratory and should reuse DOC001 if adopted. These are
directions to schedule through separate reviews, not additions to
the current function-value implementation.
