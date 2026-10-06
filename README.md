# Sprig bootstrap

Sprig is a provisional small functional language targeting ordinary Go.
Stage 0 is implemented in PureScript. This repository implements one checked
vertical slice plus closed algebraic data types with exhaustive nested
`match` (A001). Polymorphism, HKTs, classes, and rows are planned.

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
node scripts/sprig.mjs emit examples/answer.sprig .build/answer.go
node scripts/sprig.mjs build examples/answer.sprig .build/answer
.build/answer
node scripts/sprig.mjs run examples/answer.sprig
```

Both execution paths print `42`. `emit` writes canonical deterministic Go;
`build` invokes Go on a temporary source file; `run` builds and executes a
temporary binary. Destinations are explicit and may be overwritten.
Diagnostics are JSON on stderr with stable tags and source spans; source
rejection exits 1, incorrect CLI usage exits 2. Boundary errors use E_IO or
E_TOOL. The compiler is a Node executable using compiled PureScript modules,
not yet a native Go compiler executable.

## Where to continue

- [Implementation plan](docs/plans/bootstrap.md)
- [Progress](docs/progress.md)
- [Language specification](docs/language.md)
- [Architecture](docs/architecture.md) and [decisions](docs/adr/001-slice.md), [ADR 002](docs/adr/002-polymorphic-lowering.md)
- [Engineering rules and gate coverage](docs/engineering.md)
- [Reference provenance](docs/provenance.md)
- [Self-hosting chain](docs/bootstrap.md)
- [Local backlog](BACKLOG.md)

Closed ADTs and exhaustive matching are implemented (see
[ADR 003](docs/adr/003-closed-adts.md), [ADR 004](docs/adr/004-five-layers.md)
and examples/shapes.sprig). The compiler is organized in five layers: Domain,
Features, Format, Runtime, Program ([architecture](docs/architecture.md)).
The next milestone is chosen by the user after the final A001 review;
[progress](docs/progress.md) records the evidence.
