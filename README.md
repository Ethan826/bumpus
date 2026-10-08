<p align="center">
  <img src="assets/branding/bumpus-logo.png" alt="Bumpus hound logo" width="240">
</p>

# Bumpus bootstrap

Bumpus is a provisional small functional language targeting ordinary Go.
The name is for the Bumpus hounds of *A Christmas Story*, chosen because
"Sprig" collided with Masterminds/sprig in the Go ecosystem.
Stage 0 is implemented in PureScript. This repository implements one checked
vertical slice plus closed algebraic data types with exhaustive nested
`match` (A001), structural comparison operators `== != < <= > >=` on every
type, and printing of whatever `main` returns (A003, in final review).
Polymorphism, HKTs, classes, and rows are planned.

## Prerequisites and fresh checkout

Install these tools on PATH: Node >=22.5.0, PureScript 0.15.16, Spago 1.0.4,
purs-tidy 0.11.1, and Go 1.26.4 (the tested Go version). For example:

```sh
npm install -g purescript@0.15.16 spago@1.0.4 purs-tidy@0.11.1
```

Install Go using its official distribution. On platforms without a PureScript
npm binary, use the matching official release and verify its checksum.
There are no local npm dependencies. PureScript packages are pinned by
spago.yaml and spago.lock; the style checker is a separate workspace package.

From the repository root, the single verification command is:

```sh
npm run verify
```

First build requires access to the PureScript registry and package downloads.
Spago's cache is scoped to `.build/home` by scripts/cache.mjs because the
sandbox cannot write the normal user cache. An existing Spago cache can be
seeded there for offline work; see docs/findings.md. Do not change HOME.
The CLI defaults Go's cache to `.build/go-cache` when GOCACHE is unset;
test subprocesses select that workspace cache explicitly.

The initial session verified cached builds; npm package installation could
not be tested because registry.npmjs.org DNS was unavailable in its sandbox.
That environment limit is recorded as F001 in BACKLOG.md.

## Use

```sh
npm run build
node scripts/bumpus.mjs emit examples/answer.bumpus .build/answer.go
node scripts/bumpus.mjs build examples/answer.bumpus .build/answer
.build/answer
node scripts/bumpus.mjs run examples/answer.bumpus
node scripts/bumpus.mjs run examples/tree.bumpus
```

Both execution paths print `42` for the answer example. `main` may return any
type: the executable prints the value in the coverage-witness format (`5`,
`true`, `Node(Leaf, 1, Node(...))`, negative integers with `-`), and
examples/tree.bumpus prints a binary search tree. Comparisons are built in,
non-chaining and looser than `+`, with one structural order (constructor
declaration order, then fields left to right; ADR 005). `emit` writes
canonical deterministic Go; `build` invokes Go on a temporary source file;
`run` builds and executes a temporary binary. Destinations are explicit and
may be overwritten. Diagnostics are JSON on stderr with stable tags and
source spans; source rejection exits 1, incorrect CLI usage exits 2. Boundary
errors use E_IO or E_TOOL. The compiler is a Node executable using compiled
PureScript modules, not yet a native Go compiler executable.

## Where to continue

- [Language direction, effects and future targets](docs/plans/2026-10-08-language-direction.md)

- [Implementation plan](docs/plans/bootstrap.md)
- [Progress](docs/progress.md)
- [Language specification](docs/language.md)
- [Architecture](docs/architecture.md) and decisions:
  [ADR 001](docs/adr/001-slice.md),
  [ADR 002](docs/adr/002-polymorphic-lowering.md),
  [ADR 005](docs/adr/005-structural-order.md),
  [ADR 006](docs/adr/006-nesting-limit.md)
- [Engineering rules and gate coverage](docs/engineering.md)
- [Reference provenance](docs/provenance.md)
- [Self-hosting chain](docs/bootstrap.md)
- [Local backlog](BACKLOG.md)

Closed ADTs and exhaustive matching are implemented (see
[ADR 003](docs/adr/003-closed-adts.md), [ADR 004](docs/adr/004-five-layers.md)
and examples/shapes.bumpus). The compiler is organized in five layers: Domain,
Features, Format, Runtime, Program ([architecture](docs/architecture.md)).
Comparison and printing are specified in [language](docs/language.md) and
[ADR 005](docs/adr/005-structural-order.md). Milestone A003 is merged. G001
(applicative parser combinators; nesting deeper than 128 levels is the
E_NESTING diagnostic, [ADR 006](docs/adr/006-nesting-limit.md)) is Done on
branch g001, pending a scoped re-review, and is not merged.
[Progress](docs/progress.md) records the evidence.
