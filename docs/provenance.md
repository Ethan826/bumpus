# Provenance and licensing audit

2026-10-08 language direction: user preferences and conceptual discussion of
PureScript, Rust MIR, ZIO and Koka are recorded with primary-source links in
docs/plans/2026-10-08-language-direction.md. No external implementation or
reference code copied; no platform backend or effect design implemented.

2026-10-08 open error rows: inspected trailmapper/AGENTS.md "Errors are
rows, combined like the environment", src/Domain/Units/Error.purs,
src/Domain/Geo/Types.purs, src/Domain/Route/Build.purs and
src/Program/Headless.purs. Recorded conceptual influence in language-direction:
open family rows, caller composition without conversion wrappers, context-only
wrapping and closure at handling boundaries. Bumpus signatures are independent
syntax proposals; no reference implementation copied or modified.

2026-10-08 standard-library direction: inspected official Rust Option/Result,
PureScript Maybe/Either and Haskell List API documentation for naming and
helper semantics. STD001 records an independently written coverage brief
and candidate names; no library implementation copied.

Inspected 2026-10-07. ~/Desktop/mileahead was absent; the current MileAhead
reference was ~/Desktop/trailmapper. Syllogic was ~/Desktop/lsatchapelhill.
The destination workspace was empty. Reference projects were read-only;
a later explicit request for a MileAhead guidance edit was sandbox-rejected.

No root LICENSE or package.json license grant was found in either reference.
No substantive reference code, prose, tests, product logic, customer data,
credentials, infrastructure, or local skill bodies were copied. All project
implementation and checks were written independently. The following are
conceptual influences, with deliberately project-specific adaptations.

| New artifact/rule | Original inspected path | Why useful and what changed |
|---|---|---|
| AGENTS.md, engineering.md | trailmapper/AGENTS.md, CLAUDE.md, README.md | Failure ownership, explicit done/evidence, readability, 250-line cap. Local backlog replaces remote workflows; no duplicated rule prose. |
| spago.yaml, build wrapper | trailmapper/spago.yaml, package.json, .tool-versions | Strict/pedantic packages, compiler/set pins. Minimal compiler deps and workspace-local caches; no app packages. |
| typed errors/internal IR | trailmapper/src/Domain/Span.purs; AGENTS.md boundary/constructor sections | Refined construction and hidden constructor boundary. Compiler phases and checked IR replace domain units; access constrained by graph. |
| dependency gate | trailmapper/scripts/check-layers.sh; tools/checks/src/Checks/Layers/Config.purs, Partial.purs | Parse actual imports and defend effect boundaries. Independent purs graph allowlist, not copied CST layer implementation. |
| Style.Check/format/width | trailmapper/scripts/check-readable.sh; tools/checks/src/Checks/Readable.purs, Eliminators.purs; AGENTS.md lines 340–663 and formatting section; .tidyrc.json | where, named transformations, branch helpers, eliminators, Unicode/80 columns. Independent small CST checker; some budgets remain manual. Explicit user steering strengthens eliminator rule to record builders. |
| line/suppression gates | trailmapper/scripts/check-file-length.sh; check-escape-hatches.ts; tools/checks/src/Checks/Partial.purs | Tooling/tests obey their own limits; no disabled gates. Independent checker with no exemption file. |
| negative/regression tests | trailmapper/scripts/check-negative.sh; AGENTS.md failure ownership; test/Test/Domain/Span.purs | Test invalid programs, exact diagnostics, isolate mutation, prove defect sensitivity. Bumpus inputs replace PureScript unit-type negative cases. |
| properties/reference execution | trailmapper/test/Test/Domain/Span.purs; README.md reference implementation section; AGENTS.md Testing lessons | Compare against independent expectations and real execution. Seeded syntax trees/BigInt oracle replace geometry tests. |
| documentation drift | trailmapper/scripts/check-claude-md-drift.sh; lsatchapelhill/apps/api/src/big-five-drift.test.ts; both CLAUDE.md files | Avoid stale guidance. Single AGENTS source plus CLAUDE pointer rather than duplicated sections needing regeneration. |
| pure core/shell/errors | lsatchapelhill/AGENTS.md Core principles, layering, constructors; CLAUDE.md API architecture; apps/api/eslint.config.js | Immutable types, explicit dependencies, refined ingress and tagged failures. PureScript Either and Node boundary replace Effect TypeScript/HTTP/storage. |
| durable plan/progress/backlog | lsatchapelhill/AGENTS.md Definition of done, Where findings go, handoff sections; README.md; apps/api/vitest.unit.config.ts | Acceptance evidence and findings persist. Local artifacts, no SaaS requirements or issue publishing. |
| local skill assessment | trailmapper/.agents/skills/effect-ts/SKILL.md; lsatchapelhill/.agents/skills/api-endpoint-pattern/SKILL.md, tenant-scoped-state/SKILL.md; docs/agent-skills.md | Inspect stack-specific guidance and reject irrelevant adoption. No Effect, endpoint, tenant, or database skills installed here. |
| coverage algorithm | Maranget, "Warnings for pattern matching", JFP 2007 (published paper) | Usefulness U(P,q) and the witness algorithm I. Implemented independently from the paper's description in Features.Check.Usefulness, extended with inhabitedness; verified against a brute-force oracle that does not use the algorithm. No code copied. |
| five layers, ports | trailmapper/AGENTS.md "Layers, and where PureScript stops" and "Dependencies are values"; trailmapper/docs/writing/2026-09-16-an-svg-is-not-a-drawing.md | Layers named for what changes; core returns a reading and renderers write text; ports as values. Conceptual only: Bumpus's layer names, Problem ADT, Host records and gate are new; no code or prose copied. |

Third-party compiler libraries arrive through pinned normal Spago packages,
not vendored reference source; the style parser is isolated in its own package.
Earlier planning-skill research is superseded by the explicitly requested
installation below; docs/planning-skills.md records the adopted workflow.

## Installed third-party skills

Explicitly requested Superpowers installation completed 2026-10-07 using
bunx skills, project-local in .agents/skills. All 15 skills and their supporting
files are upstream material from obra/superpowers, pinned to
8ca22dba9a94f28898bbce59f2537ff4d87c747d. Source paths/hashes are recorded in
skills-lock.json; MIT copyright/license notice is preserved in
.agents/skills/SUPERPOWERS-LICENSE. These files are licensed upstream copies,
separate from independently written Bumpus code and read-only reference projects.

## Waxwing branding (2026-10-09)

The user supplied assets/branding/waxwing-{logo,mark}.svg, the transparent
logo PNG, white preview and waxwing-README.md during the naming migration.
They were copied byte-for-byte from the main checkout to the FX001 worktree.
The supplied notes describe an editable vector recreation of the user's
minimal-flight-lines concept (concept 4), with an outlined Times New Roman
wordmark approximation, navy #10212D and coral #BD6048. These supplied notes
are preserved; no new artwork or third-party source code was generated or
copied for this migration. Historical Bumpus branding provenance remains in
assets/branding/bumpus-README.md with the original image.

2026-10-10 modules and instance selection: conceptual comparison of official
fp-ts Semigroup, PureScript module, Rust visibility/coherence, OCaml module,
TypeScript module-theory and GHC orphan-warning documentation. Source links
and independent design questions are in
docs/plans/2026-10-10-modules-and-instance-selection-direction.md. No external
implementation copied; no module, class or evidence mechanism implemented.

2026-10-10 Schema direction: user supplied
https://github.com/rae-hill/schemata-ts. Consulted its README and linked
Schema interface documentation, and official Effect v4 Schema introduction/
transformation docs. Conceptual influence: separate encoded/domain types,
Schemable interpreters, parsing, codecs and arbitrary derivation. Recorded
independently in docs/plans/2026-10-10-schema-direction.md; no implementation
code copied and no claims of a complete source/library audit.

2026-10-10 Schema follow-up: consulted official io-ts Schema/Schemable APIs,
Effect SchemaAST and advanced-usage docs, ZIO Schema introduction and
Kiselyov's tagless-final research overview. Recorded conceptual precedents
and representation tradeoffs in schema-direction. No source code copied.
