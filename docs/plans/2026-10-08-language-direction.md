# Bumpus language direction and planning handoff

Recorded 2026-10-08 at the user's request to commit the current discussion.
Status: durable direction and hypotheses, not an implementation spec.
Each subsystem needs its own reviewed design and implementation plan.
P001 remains the active approved delivery; this adds no work to its scope.

## Intended language and audience

The user wants a language they enjoy: practical qualities associated with
Rust, a stronger commitment to functional programming, and PureScript-like
capabilities with more Algol-like syntax. Row polymorphism is a central
hypothesis, not a secondary convenience. Go is the first target because
the user's current job uses Go and they dislike working in it.

Long-term ambition: a well-implemented language usable for full-stack web
development and potentially native applications. Language semantics and
platform bindings should remain distinct as additional targets develop.
Rust influence does not settle ownership, borrowing, or memory management.
Haskell influence does not settle laziness or every advanced type feature.

## Early-release priorities

- Rank-1 polymorphism and parameterized ADTs (P001).
- HKTs and kind checking (K001), classes and dictionary elaboration (C001).
- Row-polymorphic records (R001), structural service composition, and an
  explicit monadic effect design (FX001).
- Useful diagnostics, predictable semantics, ordinary platform integration.

Higher-ranked types, GADTs, and type families are deferred for the early
release. They are not required to establish the application architecture
hypothesis. Rows do not replace their general expressive power; the aim is
to avoid needing those mechanisms for common application composition.
Polymorphic operations stored in service records may eventually require
higher-ranked types; early designs should expose that boundary explicitly.
Ordinary service records also need function values and their typing/lowering;
that prerequisite needs planning rather than being assumed implemented.

C001's existing direction remains: a Prelude, Eq/Ord as ordinary classes,
derive, and several selectable instances per type without mandatory
newtypes. Instance identity and safe use of instance-sensitive collections
remain design questions. No new class syntax is decided here.

## Row-polymorphism and application architecture hypothesis

Functions should express the services they need while accepting a larger
environment. Ordinary records of operations should support explicit
dependency injection and substitution of real or fake services. Combining
functions should compose requirements without a nominal environment type
for every combination.

The desired experience is ZIO-like application composition without requiring
application authors to assemble free/freer monads, transformer stacks,
layer hierarchies, or custom interpreters. This is a usability objective;
it does not prohibit a runtime interpreter or internal lowering technique.

Keep these concepts separate during design:

- Record rows describe service environments and operations.
- Variant rows could describe extensible typed errors; they are discussed,
  not approved for the early release. R001 still defers extensible variants.
- Effect rows, if chosen, describe effect requirements; record rows alone
  do not imply an effect-row system.
- An effect abstraction supplies sequencing and execution semantics.

Proposed acceptance scenario for the row/effect designs: compose services
with overlapping requirements, provide a larger environment, replace one
service with a fake, preserve unrelated fields, and obtain readable types
and useful missing-capability diagnostics. Decide conflicting labels and
field types explicitly; no implicit overwriting rule is chosen here.
This scenario is a proposed test brief, not verified language behavior.

## Effects need a separate design: FX001

Current roadmap coverage is insufficient: I001 mentions effect sequencing
inside Go FFI work, and docs/bootstrap.md needs an explicit effect boundary
for self-hosting. Neither specifies source-language monadic effects.
The compiler's own monadic Host ports are not Bumpus language support.

Design FX001 in coordination with R001, K001, C001, and I001. Decide:

1. The effect type and distinction between constructing and running it.
2. Bind/pure operations, laws, sequencing syntax, and evaluation order.
3. Service-environment requirements and how composition/provision works.
4. Typed failures, recovery, and separation from runtime defects.
5. Resource acquisition/release and cleanup on failure.
6. Whether the initial scope includes async execution, cancellation,
   concurrency, or only synchronous effects; those are not promised here.
7. Platform bindings and lowering, with Go as the first implementation.

Rows can simplify requirements but do not provide scheduling, cancellation,
or resource safety by themselves. A coherent implementation is still
needed. No Effect/IO/ZIO-shaped type, interpreter, or runtime is selected.
I001 retains foreign-value validation and Go integration; FX001 owns the
language effect semantics. Effects must respect ADR 001's explicit
sequencing requirement rather than rely on incidental Go evaluation.

## Intermediate representations and future targets

The user clarified that "hostable" referred to the inspectable intermediate
representations in Rust Playground, rather than primarily embedded scripting.
The relevant direction is a target-independent, inspectable lowered IR.
Custom bytecode and a VM are alternatives discussed, not selected work.

P001's checked generic IR and separate specialization establish a useful
boundary. A002 is the existing concrete opportunity for target-neutral
match lowering. Proposed future lowered IR makes calls, control flow,
constructor operations, and effects explicit; target-specific layouts,
allocation and calling conventions belong below the shared semantic layer.
The exact IR shape and placement relative to specialization need a design.
Textual inspection need not imply a stable serialized or binary format.

Routes considered:

- Go to WASM: retain Go runtime and use its browser/WASI build support;
  needs host integration and compatible foreign bindings.
- LLVM: add lowering, data layouts, memory management, linking and runtime
  support; LLVM can also target WASM, but supplies no garbage collector.
- Direct WASM: choose linear-memory or WasmGC representation, host imports,
  exports and runtime support.
- Bumpus VM: useful for a concrete embedding need, but requires its own
  execution, memory, interface and resource-control design.

Assistant recommendation, not a user-selected target: JavaScript alongside
Go is a useful earlier full-stack route; assess it with a browser UI and
Go service sharing pure domain modules and explicit serialization contracts.
Native application integration remains an ambition with no selected UI
framework, OS API, runtime or schedule. Self-hosting can continue through Go
independently of additional output targets.

## Planning sequence and evidence

Continue P001 as approved. Do not expand its implementation with effects,
rows, a VM, or another backend. Design each next subsystem independently,
with exact interfaces, negative cases, properties, meaningful regression
mutants, and the existing verification discipline. No reorder of approved
milestones is authorized by this record.

Recommended planning probes: the overlapping-service scenario above, then
a small full-stack example exercising rows, effects, shared pure logic and
foreign boundaries. Use their results to decide additional targets.
No execution method for these new milestones has been selected.

## Conceptual references

No reference source code is copied or licensed for reuse by this record.

- [PureScript](https://www.purescript.org/): FP, rows and JavaScript interop.
- [Rust MIR](https://rustc-dev-guide.rust-lang.org/mir/index.html):
  inspectable intermediate representation and explicit control flow.
- [ZIO contextual types](https://zio.dev/reference/contextual/):
  service requirements, typed failures and results.
- [ZIO resources](https://zio.dev/reference/resource/): execution guarantees
  beyond environmental typing.
- [Go WASM](https://go.dev/wiki/WebAssembly) and
  [LLVM GC](https://llvm.org/docs/GarbageCollection.html): target/runtime
  distinctions.
