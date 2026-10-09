# Self-hosting roadmap and reproducible seed

- Stage 0: current PureScript compiler emits Go from Waxwing source.
- Stage 1: a compiler implemented in Waxwing is compiled by Stage 0 into Go,
  then built into a native executable.
- Stage 2: Stage 1 compiles that same Waxwing compiler source into Go.
- Stage 3: Stage 2 compiles the same source again.

Compare canonical generated-Go bytes for Stage 1 -> Stage 2 -> Stage 3 with
identical inputs, options, ABI, and specialization ordering. Also run the same
positive executable suite, diagnostic/rejection suite, property/reference
suite, and regression witnesses against every stage. Record compiler/input
hashes and toolchain versions. Equal Go is useful convergence evidence; it
is not proof of correctness or independence of shared defects.

Preserve Stage 0 sources, locks, grammar, tests, and their reproducible build
instructions permanently. bootstrap/answer.go is a checked example snapshot,
not a compiler bootstrap snapshot. Once Stage 1 exists, preserve its canonical
compiler-generated Go plus checksums and Go build instructions as a second
seed. Rebuilding from this snapshot must not require an existing Waxwing binary.

Self-hosting needs strings, ADTs, pattern matching, collections, recursion,
modules, diagnostics, and a small explicit effect/Go FFI boundary. It does not
require replacing Go's backend or runtime. Before porting the compiler, port
small scanner/parser components and compare them with Stage 0. Keep Stage 0
as a behavioral/rejection reference while the new implementation grows.
