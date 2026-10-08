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
Rust-like pragmatics here mean Result-style errors, exhaustive matching,
useful diagnostics and dependable tooling. They do not settle ownership,
borrowing, or memory management.
Haskell influence does not settle laziness or every advanced type feature.

## Early-release priorities

- Rank-1 polymorphism and parameterized ADTs (P001).
- First-class function types, lambdas, closures and Go lowering (FN001),
  after P001 and before C001, R001 and FX001.
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
FN001 should supply function values for service records, continuations for
bind, deferred computations, and explicitly passed instance values.

## Function values and joint class/record design

The user requires common FP standard-library helpers with approachable
names informed by Rust, rather than historical abbreviations or joke
names. STD001's coverage/naming brief is
[standard-library direction](2026-10-08-standard-library-direction.md).
Deliver supported helpers after FN001 and coordinate generic operations,
modules and practical data APIs with K001/C001, M001 and D001 respectively;
this adds no work to FN001's approved scope.

Bumpus currently has no function values, lambdas or closures. Design FN001
as its own milestone. Go closures offer a lowering route, but the design
must specify function typing, captured values, evaluation order and how
specialization discovers referenced functions. A polymorphic named function
used as a value should be instantiated at its use site; independently
polymorphic function fields remain outside the initial rank-1 scope.
Proposed tests: passing and returning functions, captured locals and
shadowing, separate concrete uses of a generic function, and invalid calls.

C001 and R001 need a joint design review before separate implementation
plans. Explicitly selected instances and service environments may both be
records of functions. Decide whether an instance is an ordinary record,
whether class selection adds any distinct mechanism, and how evidence and
instance identity are preserved. They may become one design; do not assume
two independent selection/representation systems. This does not commit to
Scala implicits or OCaml modular implicits.

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

ADR 002 currently specializes row-polymorphic functions to concrete record
layouts. Composed environments can produce many distinct row applications;
the R001/FX001 design must quantify key counts and code growth in this
scenario, then choose a strategy. Evaluate shared dictionary/accessor-passed
representations when layouts multiply, alongside bounded specialization.
A fallback is not selected; introducing one would revise ADR 002's current
reservation of a boxed fallback for separate compilation. Independently
polymorphic operations stored in records are a separate typing and lowering
problem not supported by P001, not merely another concrete row key.

## Effects need a separate design: FX001

Current roadmap coverage is insufficient: I001 mentions effect sequencing
inside Go FFI work, and docs/bootstrap.md needs an explicit effect boundary
for self-hosting. Neither specifies source-language monadic effects.
The compiler's own monadic Host ports are not Bumpus language support.

Design FX001 after FN001, coordinated with R001, K001, C001 and I001.
Compare two design families explicitly: ZIO-like environment/error/result
computations and Koka-like algebraic effects with effect rows and handlers.
Evaluate inference, service provision, typed errors, resources, lowering and
the amount of machinery visible to application authors. Neither is selected.
Decide:

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

### Proposed `do` notation

Recorded 2026-10-08 at the user's request. This is a sequencing proposal
for FX001, not approved syntax or authorization to implement effects.
Make `do` an expression elaborated into bind and lambdas. Illustrative
syntax, including block punctuation and `<-`, remains subject to design:

```bumpus
fn profile(id) =
  do {
    user <- fetchUser(id);
    preferences <- fetchPreferences(user.id);
    logAccess(user.id);
    pure(renderProfile(user, preferences))
  };
```

Its proposed meaning is:

```bumpus
bind(fetchUser(id), fn(user) =>
  bind(fetchPreferences(user.id), fn(preferences) =>
    bind(logAccess(user.id), fn(_) =>
      pure(renderProfile(user, preferences))
    )
  )
)
```

`name <- computation` scopes a successful result over the rest of the
block. A computation without a binding discards its result. The final
expression supplies the resulting computation; `pure` lifts an ordinary
value. The selected abstraction determines sequencing: Result-like bind
bypasses later continuations on failure; a deferred effect constructs a
computation that performs the operations when run. `do` itself provides
neither scheduling nor resource cleanup. The effect design must explain
how Bumpus's strict evaluation distinguishes construction from execution.

For service-oriented effects, aim to infer the combined service
requirements and typed failures, with real or fake services supplied at
the execution boundary and no user-assembled transformer stack. How rows
combine, and whether errors use variants, remain separate design choices.

FX001 must decide how a block selects bind/pure evidence, coordinated with
C001's explicit instance selection. Also decide local pure bindings,
pattern bindings and their failure behavior, and diagnostics for mixing
incompatible computations. FN001's deferred local-binding form is not
implicitly authorized by this proposal.

If FX001 chooses algebraic effects with handlers, ordinary sequential
calls may be the natural effects syntax; generic monadic `do` can remain
a separate facility. Do not assume the effect representation or either
surface syntax is selected by recording this discussion.

### Algebraic effects and open-row syntax direction

Recorded 2026-10-08 at the user's request following the Koka discussion.
Evaluate direct-style algebraic effects: functions request typed
operations, scoped handlers provide their implementation, and effect rows
track requirements. This aligns with service substitution without
user-assembled transformer stacks. Generic monadic `do` can remain a
separate facility. Handler continuation behavior (normal return, abort,
or multiple resumptions), deferred computations, and runtime lowering
still require FX001's design; no implementation is authorized here.

The user favors familiar composition/spread notation over single-letter
open-row tails. Candidate effect syntax is `with Log + ...effects`:
`+` combines requirements and `effects` names the remaining row. The
outer annotation syntax is still provisional. It denotes requirements,
not execution order, environment mutation, or automatic handler setup.

The named rest connects requirements across higher-order APIs. A callback
requiring Database would give a logging wrapper Log plus Database; a pure
callback would give it only Log. Inferred row polymorphism should normally
establish that relationship without explicit source annotations. Widening
can permit extra effects but does not itself specify which callback's
requirements an output preserves. An alternative shorthand such as
`requiring Log` could implicitly introduce an open row; whether bare
annotations are open or closed remains a design decision.

Proposed quantification: `effects` is a user-chosen row-variable name,
not a reserved word. Generic function signatures may implicitly quantify
it universally, as ordinary type variables are quantified, rather than
requiring a written `forall`. It can be instantiated with different rows
at different calls; it is not an existentially hidden fixed row. Explicit
quantifier syntax and variable scoping remain to be designed.

Keep record rows separate. `forall r. { log: Log | r }` describes a record
with a named field; a familiar candidate spelling is
`{ log: Log, ...services }`. Under R001's unique-label direction, the rest
must lack `log`. The compiler should infer routine well-formedness
constraints; record merging may need additional row relationships.
Record labels and lack constraints do not automatically apply to effect
rows, whose duplicate/handler semantics require their own decision.

User decision: explicit constraint syntax on effect rows is a future
feature, outside the initial FX001 scope. Preserve the possibility of
constraints on a named rest, but do not implement an effect-row `where`
language or general traits over rows in the first effects release.
Internal row inference and well-formedness remain necessary. This
deferral does not remove R001's planned record-row lacks constraints.

### MileAhead's open error rows and Bumpus surface syntax

Inspected 2026-10-08 at the user's request. The MileAhead reference is
`../trailmapper` (`../mileahead` is absent). Its AGENTS.md section
"Errors are rows, combined like the environment", Domain.Units.Error,
Domain.Geo.Types, Domain.Route.Build and Program.Headless establish a
specific pattern not previously captured by the general typed-error
discussion here. Conceptual influence only; reference files remain
read-only and no implementation is copied.

Preserve these properties as a design brief:

- Each domain defines a concrete error family and one row label carrying
  that whole family, rather than a label for every failure case.
- Leaf functions leave the error row open. Callers instantiate compatible
  rows so composing fallible operations combines families without
  conversion wrappers or a global application-error ADT.
- Errors pass through unchanged. Wrap only when adding real context,
  such as an input position; the contextual error may contain an inner
  composed error row.
- Close the row where errors are handled exhaustively, or in tests that
  need closed comparison/rendering. Partial handling should preserve and
  forward the unhandled remainder.

Candidate Bumpus syntax avoids exposing PureScript's `Variant` carrier,
`inj`, proxies and `on`/`case_` plumbing. An error-type expression could
denote a tagged open sum directly:

```bumpus
fn validateName(text: Text): Result(ValidationError + ...errors, Name);
fn saveWidget(widget: Widget): Result(DbError + ...errors, Widget);
fn createWidget(text: Text):
  Result(ValidationError + DbError + ...errors, Widget)
  with Clock + Random + Database;
```

These are schematic signatures, not implemented syntax. `errors` is an
ordinary user-chosen error-row variable name, not a reserved word or an
existential. Generic signatures implicitly quantify it universally; each
caller can instantiate a compatible row. Only the spread punctuation has
special syntax. The closed form omits the spread. `Err` should infer
injection of an ordinary
error-family value into the required sum; ordinary `match` should expose
its cases with exhaustiveness checking. The compiler must retain distinct
family identity and payloads, reject incompatible row compositions, and
avoid requiring explicit widening calls. Hiding the carrier does not
eliminate tagged-sum semantics or runtime layout work.

In the direct-style effects candidate the same error sum can parameterize
`Failure(ValidationError + DbError + ...errors)`. A handling boundary can
reify that channel as Result. Expected typed failures remain distinct from
runtime defects, and value-level error rows remain distinct from operation
requirements and service-record rows.

R001 currently defers general extensible variants. This brief exposes a
specific need for open error sums; FX001/R001 must review whether to add
error-specific support or broader extensible sums and explicitly revise
scope before implementation. Type-identity versus label-based family
selection, sum syntax, contextual nesting, matching, inference, Go layouts
and specialization growth are open design questions. Explicit effect-row
constraint syntax remains deferred; internal error-row solving is separate.

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
Default to test: lowered IR after specialization, where concrete operations
are monomorphic and target-neutral, above target layouts. P001 builds that
boundary; A002 can give the lowered IR concrete work. The exact shape and
any generic lowering before specialization still need a design.
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

Full-stack use also needs strings/text with explicit encoding semantics,
numeric types beyond Int32 with defined arithmetic, practical collections,
and modules/interfaces (M001). Track these foundations under D001 for
separate focused designs; sharing pure modules across targets presupposes
M001 and compatible public data/serialization contracts. None is supplied
by an additional emitter alone.

## Planning sequence and evidence

Continue P001 as approved. Do not expand its implementation with effects,
rows, function values, a VM, or another backend. Design each subsystem,
with C001/R001 considered together to avoid overlapping mechanisms,
with exact interfaces, negative cases, properties, meaningful regression
mutants, and the existing verification discipline. Updated planning order:
FN001 follows P001 and precedes C001, R001 and FX001. Their joint-design and
other prerequisite dependencies must be resolved before implementation;
the current P001 delivery and its execution method are unchanged.

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
- [Koka](https://koka-lang.github.io/koka/doc/book.html): effect rows and
  algebraic handlers as a contrasting effects design family.
- [Go WASM](https://go.dev/wiki/WebAssembly) and
  [LLVM GC](https://llvm.org/docs/GarbageCollection.html): target/runtime
  distinctions.
