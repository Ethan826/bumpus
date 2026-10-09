# Effects, handlers and typed failures: design (FX001)

Status: written spec, revised after the user's whole-spec review
(2026-10-09): FN001 evaluation order, one dependency model, `ctx` mode over
emitted IR, handler restrictions, confirmations; section 6 (diagnostic
quality) added at the user's request; approved for implementation
planning by the user 2026-10-09. Direction
decisions and sections 1-5 were settled section by section with the user
on 2026-10-09; only the item under "Awaiting confirmation" remains
unconfirmed. Nothing is implemented, and no implementation
plan exists yet. Background: docs/plans/2026-10-08-language-direction.md
(FX001 sections) and BACKLOG.md FX001.

## Direction decisions (user, 2026-10-09)

1. **Family: Koka-style algebraic effects, restricted now, resume-ready.**
   Direct-style effect operations, effect rows and scoped handlers.
   FX001 accepts only immediately resuming (`fun`-like) operation clauses
   and abort-only failures, lowered to Go by evidence passing (handlers as
   hidden records of functions; aborts as structured early exits). No
   CPS or goroutine continuations. Handler syntax distinguishes general
   control (`ctl`-like) clauses from day one so that general resume can be
   added in a later milestone without changing the meaning or the Go of
   existing programs. (The expectation recorded here that row-keyed
   specialization would confine CPS is revised by section 4: rows are
   erased.) Constraints carried forward: cleanup must stay sound once a
   continuation can be captured and dropped; a continuation may not be
   captured across a foreign Go frame (I001). ZIO-like `Effect(R, E, A)`
   values were rejected for FX001; generic monadic `do` stays with K001/C001.
   Cost accepted: no user-defined async, generators, coroutines,
   schedulers or backtracking until general resume. A future JavaScript
   target (J001) would pull much of that work forward.
2. **Prerequisites folded in.** FX001 adds Unit, a block expression with
   sequencing and local bindings (`{ let x = e; e; e }`, absorbing FN002),
   and a built-in Console effect whose `print` reuses ADR 005 printing for
   any printable type. No Text (D001 stays separate).
3. **Typed failures are effect labels.** `Fail(E)` row entries keyed by the
   error type's identity form open error families: composition by row
   unification without wrappers, partial handling forwards the remainder,
   a `handle` clause can reify one family as `Result`, wrapping only adds
   context.
   Value-level open sums remain deferred with R001's variants; the
   direction document's `Failure(A + B + ...errors)` spelling may become
   sugar over the row form.
4. **Synchronous only.** Goroutine-backed fork/await/race/timeout and
   cancellation are a follow-up milestone on the same evidence model.
5. **Cleanup now.** A cleanup form (spelled `defer`, section 1) runs on
   normal exit, every abort passing through and recoverable defects
   (decision 9), specified to remain sound under future captured
   continuations.
6. **Ambient open rows.** Every signature carries an implicit, rigid,
   universally quantified ambient row; unannotated arrows in it share that
   row. Written labels exactly bound a function's own effects
   (parametricity: the body cannot perform anything through the ambient
   row, only pass through what its arguments perform). `...e` names rows
   that must differ; `with pure` marks a closed empty row; the entry
   point's row is checked closed against the built-in effects.
   Consequences to specify: readable row printing in diagnostics, a way
   to show expanded signatures (IDE001 later), and pure functions must not
   be copied per row (settled by section 4's row erasure).

7. **First-class service handlers.** A handler of immediately resuming
   clauses never mentions the handled action's answer type, so it is an
   ordinary rank-1 value (a record of operation implementations, the same
   shape as its Go evidence): `handler Clock { now() => t }` has a type
   such as `Handler(Clock)`, can be named, passed, stored or selected at
   runtime, and `with h { body }` installs it. Effects performed by its
   clauses belong to the handler's type (`Handler(Clock with Log)`), not
   to constructing it. Failure handling (`handle`) and future general-
   control handlers depend on the answer type and stay lexical forms.
8. **Scoped labels.** A row may contain a label more than once; the
   innermost handler takes the operation. This permits intercept-and-
   forward handlers and needs no lacks constraints on row variables.
9. **Defects are uncatchable; cleanup still runs.** Runtime defects are
   never caught by `handle`; they unwind to program exit with a report,
   running deferred cleanup on the way. Catching defects at
   supervision boundaries is left to the concurrency follow-up.

## 1. Syntax (section approved by the user 2026-10-09 with adjustments)

Reserved words added: `effect handler handle with let defer Unit ctl
resume`. `ctl` and `resume` are reserved for general control and rejected
with a dedicated diagnostic until that milestone. `pure` is contextual:
recognized only directly after `with` (labels are uppercase, so this is
unambiguous) and otherwise an ordinary name, keeping it free for a future
Applicative `pure`.

Effect declarations (top level):

```
effect Clock { fn now(): Int; };
effect State(s) { fn get(): s; fn put(value: s): Unit; };
```

Operations are global names called like functions under FN001's arity
rules unchanged: `now()` performs the operation; a bare zero-parameter
operation is E_ARITY `Expected now()`; an operation with parameters is a
function value when bare. A deferred zero-argument operation is written
explicitly, `fn(_: Unit) => now()`. Making zero-parameter functions
first-class uniformly is a separate decision. An operation may mention only
its effect's parameters; operation-level polymorphism is deferred.
Like field types, operation signatures have no ambient row: an
unannotated arrow in an operation's parameter or result type is `pure`,
and effects have no row parameters in FX001, so an operation cannot take
or return an effect-polymorphic callback (deferred with row parameters on
effects).

Built-in effects: `Fail(e)` with `fail(error: e)`, whose result type is
unconstrained because it never returns; `Console` with
`print(value: a): Unit` for any printable `a`, the one explicit built-in
exception to the operation-polymorphism restriction. Console is a host
effect handled only by the runtime at `main`; user Console handlers wait
for Text (D001).

Rows in types:

```
fn f(x: Int): Int with Log + Clock;              // own effects Log, Clock
fn g(f: a -> b with ...e, x: a): b with Log + ...e;
fn h(f: a -> b with pure, x: a): b;              // callback must be pure
fn safeDiv(n: Int, d: Int): Int with Fail(DivByZero);
```

**Omission is not a promise of purity; `with pure` is.** Every signature
carries an ambient row (decision 6). Every arrow without `with`, and the
signature itself when it has no `with` or a `with` without a spread, shares
that ambient row. The ambient row lets a function pass through what its
callbacks perform, never perform anything itself. `with` attaches to the
nearest arrow to its left, so `A -> B -> C with E` puts `E` on the final
stage and `(A, B) -> C with E` remains exactly `A -> B -> C with E`;
parentheses delimit it: `(Int -> Int with Log) -> Int` annotates the
parameter. `Handler(Clock with Log)` is a Clock handler whose clauses
perform Log; bare `Handler(Clock)` uses the ambient row in a signature and
is `pure` in a field or operation type (no ambient row there).

Expressions:

```
{ let t = now(); print(t); t + 1 }      // block; last item is the value
handler Clock { now() => 42, }          // first-class value; all operations
with clock { print(now()) }             // install a handler over a block
handle Ok(risky()) {                    // lexical, answer-type-dependent
  fail(error: DbError) => Err(error),
}
{ let r = acquire(); defer release(r); use(r) }
()                                      // the Unit value
```

- `let` binds a name or `_`; refutable pattern `let` is deferred.
- `handle` is the lexical form for answer-type-dependent clauses: `fail`
  clauses, one per family, now; `ctl` later. Reifying into Result needs no
  construct, but success must be wrapped explicitly (`Ok(risky())`).
- `defer e` is a block item. Deferred expressions run LIFO when the block
  exits by normal completion, typed abort or defect. Confirmed by the user
  2026-10-09: the whole expression, callee and arguments, is evaluated
  at exit (`finally` semantics), unlike Go, which evaluates arguments at
  registration; locals are immutable, so the difference is only when the
  argument expressions' own effects or divergence happen.
- Blocks, `handler`, `with` and `handle` join `if`/`match`/lambda in the
  loosest expression dispatch (`{` never starts an expression today).
- Confirmed by the user 2026-10-09: `{}` evaluates to `()` (a no-op,
  consistent with semicolon-terminated blocks); a trailing `;` discards
  the last value and makes the block `()` (Rust rule), with a `remove the
  trailing ;` hint when that causes `Expected T, found Unit`;
  `{ let x = 1 }` is E_SYNTAX `Expected ;`; discarding non-Unit values
  mid-block is allowed.
- Entry: `fn main(): T with Console` or effect-free; its row is checked
  closed. `main` prints its result after its effects, except a Unit result
  prints nothing.

## 2. Typing and rows (revised after user review 2026-10-09)

**Representation.** Every arrow carries a row: `TFun param row result`. A
row is an ordered sequence of labels and an optional tail (a rigid or meta
row variable). A label is an effect applied to types (`Clock`,
`State(Int)`, `Fail(DbError)`). Rows are a separate sort, not types; no
K001 kind system is needed, but sort and arity checking is: type arguments
and row arguments stay distinct through resolution, substitution and
specialization, and a declared type or effect with row parameters checks
the number and sort of its arguments.

**Label keys (scoped labels, decision 8).** A label's key is its effect,
except `Fail`, keyed by the resolved declared type identity of its payload
(Int, Bool or a TypeId), while the label keeps the full payload type:
`Fail(DbError)` and `Fail(ValidationError)` are distinct keys;
`Fail(Error(Int))` and `Fail(Error(Bool))` share the `Error` key and their
arguments must unify when one is matched against the other. `fail(e)`
requires `Fail(typeOf(e))`, the full type. A payload whose head is still
an unsolved meta is decided after the body's other constraints are solved
(deferred key); one that remains a meta, or is a rigid variable, is E_TYPE
`Fail needs a concrete error family`. Limitation recorded for STD001: no
fully generic helper turns an arbitrary `Result(error, value)` into a
failing computation; helpers are per family, or return Result.

Rows keep order and multiplicity. Matching takes the *first* occurrence
with the key; if its arguments do not unify, that is an error, never a
reason to try a later duplicate. No check (including the entry check)
treats a row as a set.

**Row unification** (Leijen, scoped labels, §7). Unifying `l + r1` with
`r2`: rewrite `r2` to `l' + r3` where `l'` is the first entry with `l`'s
key, producing substitution θ (extending `r2`'s tail meta with `l` and a
fresh tail if no entry exists; failing if the tail is rigid or the row is
closed: the missing-capability error); unify `l` and `l'`'s arguments;
then unify `r1` with `r3` under θ. Side condition: `tail(r1) ∉ dom(θ)`,
i.e. the rewrite must not have bound `r1`'s own tail. Without it
`Clock + ...r` against `Log + ...r` rewrites forever (r := Clock + r1',
then Log against r1' + ...); with it the pair fails. That case is a
required regression test. Loops and the inferred-depth bound follow the
existing Unify conventions (spines and rows walked iteratively).

**Signatures.** Resolve gives each signature one implicit rigid ambient
row. Written arrows without `with`, and the final stage when unannotated
or annotated without a spread, use it (`with L1 + L2` is
`L1 + L2 + ambient`); `with L + ...e` uses the named rigid variable `e`;
`with pure` is closed and empty. A declaration's own non-final stages
(declared arity n > 1) are not written arrows: each carries its own
quantified row variable, instantiated fresh per use, because those stages
perform nothing (FN001 staging).

**Execution boundaries.** Evaluation order is FN001's (design §5),
unchanged: `e(a1, …, aj)` evaluates `e`, then `a1`, then applies, then
`a2`, then applies, and so on; arguments and stage executions interleave.
Each application that completes a stage boundary runs that stage and
consumes its arrow's row: applying a value of type `A ->r1 B ->r2 C`
consumes r1 when its first argument is applied and r2 when its second is,
with `a2` evaluated between the two. For a named callee with declared
arity n, stages 1..n-1 have inert fresh rows and stage n carries the
body's row, so a saturated call is still "all arguments, then the body".
Over-application `f(a, b, c)` with `f` of arity 2 is `a`, `b`, `f`'s body
(consuming its row), then `c`, then applying the result (consuming that
arrow's row): an arity-one function returning a function runs its body
before the second argument is evaluated. Partial application evaluates its
supplied arguments, with their ordinary effects, immediately and once, and
contributes no latent body effects (`take(now())` performs Clock).
`a |> e` follows FN001's pipe order (left operand first). Required:
Console-trace probes of these orders, including over-application and `|>`.

**Consumption and opening.** The current row is the final-stage row of the
enclosing declaration, a lambda's fresh row meta, or a handler's clause
row. Consuming stage row `s` in current row `ρ`: if `s` has a tail, unify
`s` with `ρ`; if `s` is closed, unify `s + fresh` with `ρ` for this
consumption only (the coercion `pure ⊆ ρ`), leaving the value's type
unchanged. Opening is otherwise applied in exactly one place: instantiating
a *declaration* reference (function, operation, constructor) replaces a
closed final-stage row of the declaration's own stages with a fresh tail.
Never opened: rows inside parameter or field types (`with pure` there is a
demand), named row variables (instantiated by one shared fresh meta, so
relationships stay shared), and locals (parameters, lambda parameters,
`let` bindings, monomorphic). Consequence: a local of type
`A -> B with pure` passed where `A -> B with Log` is expected is a type
error; eta-expansion `fn(x) => g(x)` is the workaround (recorded
limitation, following Koka's distinction between instantiated bindings and
lambda-bound parameters, Leijen 2014 §3.2).

**Expression rules.**
- `handler L { op(x) => e, … }` performs nothing; clauses check against
  its row R; exactly one clause per operation of L; type `Handler(L with R)`.
- Handler types are neither comparable nor printable, directly or nested
  in a declared type, exactly like function types (FN001): comparison,
  `print`, `crash` and main's result reject them. Pointer or struct
  comparison would otherwise expose handler identity, which section 3
  forbids observing. Required rejection tests for all four.
- `with h { body }`, `h : Handler(L with R)`, current row ρ: body checks
  against `L + ρ`; R is unified with ρ (opened if closed, as consumption).
- `handle body { fail(error: E1) => r1, … }`: body checks against
  `Fail(E1) + … + ρ`, clauses against ρ, one shared result type; families
  not mentioned stay in ρ.
- `fail(e)`: consumes `Fail(typeOf(e))`; result type fresh.
- `defer e`: e : Unit, checked against the current row (failure during
  unwinding: section 3).
- `let x = e` is monomorphic in FX001; let-generalization would need its
  own effects-aware soundness treatment.

**Data types.** An unannotated arrow in a field type is `pure`. Effectful
stored functions and handlers use declared row parameters:
`type Job(a, ...effects) = Job(Int -> a with ...effects);`, applied as
`Job(Int, Log + Clock)`.

**Finiteness (ADR 007): a proof obligation, not a consequence.** It must
cover recursive handler installation, function-value uses and rows nested
in data types. Recursive handler installation, e.g.
`fn loop(n: Int): Int = with h { loop(n + 1) };`, forces the recursive
call's ambient row to `L + ambient`: under row-keyed specialization that is
polymorphic recursion (`loop@ρ`, `loop@L+ρ`, …), so an instantiation rule
extended to rows would reject a common pattern. Resolved in section 4:
rows do not enter specialization keys; types inside labels do, and the
declaration-graph rule bounds effect layouts.

**Entry point.** After solving, main's row, with any unsolved tail closed
to empty, must consist only of `Console` entries. Each remaining entry is
E_EFFECT (new code), e.g. `Unhandled Database in main (required by stamp
at 12:3)`, including `Fail(DbError)` families.

## 3. Handler semantics (revised after user review 2026-10-09)

**Evidence context.** Execution carries an ordered stack of installed
handlers. `with h { body }` evaluates `h`, pushes it for `body`'s extent,
then pops it. An operation goes to the innermost handler for its key in
the context current *when the operation executes* (deep, dynamically
scoped handlers). A lambda created inside `with h` and called after it is
handled by whatever is installed at the call; closures never retain
evidence. Typing makes this safe: the lambda's row includes `L`.

**Clause context.** A clause of a handler installed by `with` runs in the
context current at that `with`: without the handler itself or anything
installed inside it. A Log clause that logs reaches the next outer Log
handler (intercept-and-forward), never itself. This matches section 2's
typing (R unified with the row outside the `with`) and Koka's evidence
implementation (clauses run with handler-site evidence).

**Evaluation order** (ADR 001, strict, left to right): `with h { body }`
evaluates `h` first; `fail(e)` evaluates `e`, then aborts; `handle body
{ … }` evaluates `body` under the handler, a clause only on its family's
failure; `defer e` registers `e` when the block reaches it (an unreached
`defer` never runs) and `e` is evaluated in full at exit, LIFO.

**Cleanup context.** A deferred expression runs with the evidence context
in force where it was registered, and every handler of that context stays
available during cleanup. A block's deferred expressions run before any
enclosing `with` pops its handler, so unwinding cannot change which
logger, resource service or failure handler cleanup uses. Retaining
evidence for cleanup does not make escaped lambdas retain evidence.
Required test: cleanup invoking an operation under nested handlers while
an abort from an inner context unwinds.

**Targeted aborts.** `fail(e : E)` finds the innermost `handle` for E's key
in the context where `fail` executes and unwinds to *that instance*, not to
the nearest Go stack frame. A clause installed outside a `handle` for
DbError that fails with DbError while the body runs is not caught by that
inner `handle`: the clause runs in the outer context. Unwinding runs the
deferred expressions of every exited block, innermost first.

**Block exits.** A block activation exits for exactly one of four reasons:
normal completion, typed abort, recoverable defect, or (future) continuation
discard. Its deferred expressions run exactly once per exiting activation.
FX001 produces no discard; the event is named for general resume. Multi-
shot resumption of continuations containing `defer` is explicitly
unresolved and left to that milestone.

**Cleanup failures.** A deferred expression may handle failures internally
and complete normally, including during unwinding. Policy: if a typed abort
escapes a deferred expression while another abort or defect is pending, it
becomes a cleanup defect carrying both causes. On normal exit, the first
escaping failure becomes the pending cause; subsequent deferred expressions
run with it pending. If cleanup raises a recoverable defect, the pending
cause is retained, later causes are recorded in execution order, and the
remaining deferred expressions still run. This is a design choice that
permits useful effectful cleanup without an absence-checking mechanism
now; internal constraints could prevent failing cleanup statically, and
the deferral of user-written row-constraint syntax does not forbid them.

**Defects.** A defect is any recoverable runtime panic that is not a
targeted abort. No handler catches one; unwinding runs every deferred
expression, then the program reports once on stderr and exits non-zero
(exact report and status: section 5). Go stack exhaustion and out-of-memory
are fatal errors, not panics, and skip `defer`; "cleanup runs on defects"
holds for recoverable defects only, and the language docs say so. A
missing handler cannot occur in a well-typed program; the runtime keeps a
guard panic (`no handler for L`) as Match does.

**`crash(value: a): b`.** A built-in function, not a reserved word. Its
argument has Console's printable-value restriction, is evaluated strictly,
and then raises an uncatchable recoverable defect; its result type is
unconstrained because it never returns. The report happens once, after
cleanup, with no eager print. It requires no effect: `with pure` promises
neither termination nor freedom from defects (documented). It serves as
assertion/unreachable and makes defect cleanup testable in Waxwing. Tests:
Fail handlers cannot catch it, cleanup runs LIFO, and cleanup defects keep
the original cause. Injected runtime tests for foreign panics remain I001's.

**Resume-readiness.** FX001 preserves: (1) `defer` defined by block-exit
events, not Go mechanics; (2) aborts targeted at handler instances,
independent of Go stack position; (3) clause context and the evidence model
unchanged for `ctl`; (4) no observable behavior depends on Go stack
identity (no goroutine-local state; handler identity never compared).

## 4. Lowering (revised after user review 2026-10-09)

**Target-neutral contracts first.** The monomorphic IR (Domain.IR) gains
explicit nodes for handler construction, handler installation (`with`),
operation invocation, failure handling (`handle`) with targeted abort
(`fail`), blocks with `let`, discarded items and cleanup registration
(`defer`), `print` and `crash`. Their meaning is sections 2 and 3, not Go
mechanics. Go lowers them to context nodes and panic/recover below;
future JS, WASM or LLVM backends (J001, L001) implement the same contracts
with their own mechanisms.

**Erasure mapping: row structure is erased; types inside rows are not.**
Approach chosen: retain the ordinary type arguments needed for operation
and handler layouts; erase effect-row structure. (Rejected: a uniform
boxed operation ABI with checked typed adapters, which would allow
stronger erasure at representation and conversion cost.)

| Source construct | Go representation depends on | Erased |
|---|---|---|
| arrow `A -> B with R` | A, B (uniform `ctx` parameter) | R |
| label `State(Int)` at an operation call | effect and ground type arguments: perform function and handler struct for `(State, [Int])` | its position in the row |
| `Handler(State(a) with R)` value | handler struct for `(State, [a])` | R (clause row) |
| `handler State(…) { … }` | struct for its effect key; clauses lifted like lambdas | clause row |
| `with h { body }` | runtime lookup key = EffectId | rows |
| `Fail(Error(Int))` | runtime key = (Fail, TypeId of Error); payload stored as `any`, its full type known at the `fail` site and at the matching clause | rows |
| row-parameterized data `Job(Int, Log + Clock)` | type key (TypeId, type arguments only); fields use the uniform arrow representation | row arguments |

Scoped duplicates with different arguments (`State(Int) + State(Bool)`)
share the runtime key; section 2's first-occurrence typing guarantees the
innermost frame for the key has the layout the operation site expects, so
a perform function type-asserts the frame's handler to its own struct
(assertion failure is a guard panic, unreachable when well-typed). Effect
parameters are types only in FX001; a row cannot be a label or an effect
argument.

**Specialization keys and dependencies.** Keys are type keys (TypeId,
ground types) and function keys (FunctionId, ground types) as today, plus
*effect keys* (EffectId, ground types), one per perform-function and
handler-struct layout. One worklist (Features.Specialize) builds all three;
creating a key enqueues the layouts it depends on:
- a function key: the keys reached from its body (calls, function values,
  constructions, operation invocations, handler constructions, handler
  types and the types of its locals), as today plus effect keys;
- a type key: the type and effect keys of its constructor fields
  (`Handler(L …)` in a field reaches L's effect key);
- an effect key: the type and effect keys of its operations' parameter and
  result types (`Handler(L …)` there reaches L's effect key).
Rows are erased everywhere, so labels and types occurring only inside rows
create no key and no dependency. Every key counts toward the existing
10,000-key limit.

**Finiteness argument (to be checked as a proof in the plan).** Two
static rules bound this worklist. (A) Function keys: ADR 007's
instantiation rule, unchanged. Row structure never enters a key, so
recursion that extends rows (`with h { loop(n + 1) }`) creates none. Every
type that reaches a key through a label is built from the declaration's
signature type variables, which are part of every call's Instantiation
(Resolve's signature variables include lowercase names inside labels;
label arguments unify like any type), so a type growing through a row,
e.g. `fn r(): Unit with State(a) + ...e = with listState(…) { r() };`
forcing `a := List(a)` within a component, is rejected by the existing
rule. Holes default to the representative (Int). (B) Layout keys: the
declaration-graph rule below, over types and effects together. Required
probes: recursive handler installation, function values with effectful
rows, rows nested in data types, growing-label recursion (rejected).

**Layout dependencies (user review 2026-10-09).** Effect layouts introduce
dependencies, as the worklist above records:

```
type Box(a) = Box(a);
effect Grow(a) { fn next(): Handler(Grow(Box(a))); };
```

Constructing a `Grow(Int)` handler, even one whose `next` clause crashes,
demands `Grow(Box(Int))`, `Grow(Box(Box(Int)))`, … with no recursive call.
Fix: P001's nested-declaration rule (Features.Check.Nested, design §4.1)
extends to one reference graph over type *and* effect declarations, with
exactly the dependency edges of the worklist's type and effect keys: types
in constructor fields; types in operation parameters and results; and the
effect named by every `Handler(L …)` in either. Inside a component, every
type argument of a reference must be a bare parameter of the referring
declaration or ground; a violation is E_SPECIALIZATION (the existing
nested-declaration problem, extended to effects) at the nested reference.
Required rejection probes: `Grow`; a mutually recursive pair
(`effect A(x) { fn f(): Handler(B(Box(x))); };
effect B(y) { fn g(): Handler(A(y)); };`); a cycle crossing data and
effects (`type T(a) = T(Handler(G(List(a))));` with
`effect G(a) { fn h(): T(a); };`); and the admissible bare-parameter
version of each, which must compile. Rules (A) and (B) together are the
finiteness argument; the 10,000-key guard is a backstop, not the argument.

**Uniform `ctx` (backend choice, within the whole-program model).** The
mode is chosen over the *emitted* IR, not over code reachable from `main`:
specialization emits every monomorphic function, used or not, and an
unused function performing Clock must still compile. A program whose
emitted IR contains no operation invocation, handler construction or
handler type, `fail`, `with` or `handle` threads no context. Required
test: a pure `main` beside an unused effectful function emits `ctx` code
that builds and runs. Changing dead-code emission is a separate choice. Otherwise every function, stage,
lambda and function value takes `ctx *waxwingCtx` first, giving function
values one calling convention regardless of latent effects. All new
runtime support (context, cleanup helper, defect reporting and `main`'s
recovery wrapper) is emitted only when used, so existing programs stay
byte-identical and Console-only programs omit `ctx`; programs using
`crash` or `defer` get the runtime pieces they need without `ctx`.
PKG001 obligation: host-callable exports and separately consumed
libraries need adapters whose public calling convention does not depend
on whether the consuming application uses effects.

**Context and operations.** `waxwingCtx{key, handler any, outer, marker}`
is an immutable linked list; installing allocates a node, leaving needs no
pop. `op(args)` calls the perform function for its effect key, which finds
the innermost frame with the key and calls the clause with the frame's
`outer` (clause-context rule). Lookup is linear in installed handlers;
measured in section 5, a cached index is a follow-up.

**Targeted panics: runtime contracts.**
- Every `handle` activation creates markers with guaranteed distinct
  identity: fresh allocations of a non-zero-sized marker type (Go permits
  distinct zero-sized variables to share an address), one per family
  frame; markers are compared only by pointer.
- `fail(e)` panics with `&waxwingAbort{target, payload}` where `target` is
  the innermost frame's marker for e's key.
- Recovery happens directly in a deferred function of the lifted `handle`
  helper, as Go requires; it consumes only aborts whose target is one of
  its own markers and re-panics everything else unchanged.
- The helper returns `(result, abort)`; the matching clause runs after it
  returns, in the `handle`'s context, so clause failures and crashes
  propagate normally.
- `waxwingCleanup` (Go `defer` in the lifted block helper, recovering
  directly) preserves the pending cause, runs remaining cleanup, records
  later causes in order and applies section 3's policy.
Ordinary calls need no abort-result checks; handler installation,
deferred recovery and cleanup still have costs, measured in section 5.
Result-propagation lowering remains an alternative that would change Go,
not semantics.

**I001 obligation.** A foreign Go library could recover a panic raised by
a Waxwing callback. I001 must define the permitted callback boundary
(e.g. aborts may not cross foreign frames, or adapters re-raise) before
transparent abort propagation through host libraries is promised.

**Revision of direction decision 1.** Row erasure deliberately revises the
recorded strategy of confining future CPS through row-keyed
specialization. A conservative analysis ("can this specialized function,
or a function value applied in it, reach a `ctl` operation?") is a
possible future solution, not a demonstrated replacement; the general-
resume milestone must establish it or choose bounded row-aware
re-specialization.

## 5. Scope, testing, diagnostics and acceptance (revised after user review 2026-10-09)

**Scope boundary (user decision (b), 2026-10-09).** FX001 has no mutable
state: handler clauses are ordinary functions and Waxwing has no cells.
FX001 supports stateless fakes (fixed clock, canned results, prefixing
loggers) and call traces observable through Console output. Recording
databases and loggers are FX003 work (local state: encapsulation, escape
safety, backend representation; compare Koka-style scoped `var` with
parameterized handlers). This is a deliberate scope decision, not full
delivery of realistic test doubles.

**Diagnostics** (exact-text rows):
- E_EFFECT (new): `Unhandled Database in main (required by stamp at 12:3)`;
  `stamp performs Database, which its signature does not allow` at the
  call (rigid row); the Leijen side-condition failure.
- E_HANDLER (new): `Missing clause for now`, `Duplicate clause for now`,
  `put is not an operation of Clock`.
- E_TYPE: `Fail needs a concrete error family`; sort errors `Expected a
  type, found an effect row` and the converse; the trailing-`;` hint.
- E_SPECIALIZATION for expanding type/effect declaration cycles (the
  existing nested-declaration problem extended, section 4).
- Rejections of comparing, printing, crashing with, or returning from
  main a value whose type contains a handler (section 2).
- E_SYNTAX `General control (ctl/resume) is not supported yet`; E_ARITY
  `Expected now()`.
- Every effect diagnostic follows section 6 (provenance, row difference
  first, origin and boundary notes, distinguished kinds, bounded output).
- Row display: labels in row order, a named tail `...e`, the ambient tail
  `...` (`with Log + ...`), the closed empty row `pure`.
- Defect report (confirmed by the user 2026-10-09: one stderr report
  after all cleanup, exit status 1, and the line format below). One cause
  per line in execution order, embedded newlines escaped as `\n`; the
  first line is the original cause, every later line is prefixed
  `cleanup failed: `. A cause is rendered as `crash: V` for `crash(V)`,
  `fail(T): V` for a typed abort with payload type T, or
  `no handler for L` for the guard. T is the payload's type as
  diagnostics print it (`DbError`, `Error(Int)`). V is ADR 005's
  rendering when T is printable; when T contains a function or handler,
  V is `<not printable>` and the line keeps `fail(T)`, so typed errors
  gain no new printability restriction. Example (abort unwinding, cleanup fails):

  ```text
  fail(DbError): Timeout(3)
  cleanup failed: fail(ReleaseError): Busy
  ```

**Unifier properties** (quantified, generated inputs including repeated
keys with differing arguments, shared tails and rigid variables, not only
distinct-label permutations): a successful substitution makes the input
rows equivalent under scoped-label equality; acceptance is symmetric;
substitutions stay acyclic; distinct keys commute and same keys do not;
first-occurrence mismatch is an error; `Clock + ...r` against `Log + ...r`
fails (side condition); 1,000-label rows unify without recursion per
label. Opening: a parameter's `with pure` demand survives instantiation;
a named row stays shared; the eta-expansion limitation is pinned.

**Executable probes** (expected stdout, stderr and exit status, via
`go build`):
1. Parameterized handlers: nested `State(Int)` and `State(Bool)`; generic
   `fn constant(v: s): Handler(State(s))`; parameterized handlers reached
   through stored functions.
2. Effectful functions in row-parameterized data (`Job(Int, Log + Clock)`
   in a list) run under two handler sets.
3. Nested same-key handlers: intercept-and-forward; a logging clause
   reaches the outer handler.
4. Targeted aborts crossing unrelated handlers, including a clause failing
   past an inner `handle` of its family.
5. Error families and layouts: different `Fail` families; different payload
   instantiations of one family (`Error(Int)`, `Error(Bool)`).
6. Cleanup: two failing defers on normal exit; abort with failing cleanup;
   `crash` in cleanup; multiple recoverable defects (cause order, LIFO);
   cleanup that handles its own failure completes normally, including
   while an outer abort is pending; an unreached `defer` never runs; a
   discarded normal result after a cleanup failure.
7. Cleanup invoking operations under nested handlers while an abort
   unwinds (registration context).
8. Evaluation order traces (Console): interleaved arguments and stages,
   over-application of an arity-one function returning a function, `|>`.
   Escaped and partially applied function values: a lambda created under
   one handler runs under another at invocation; supplied argument effects
   happen immediately and exactly once.
9. Recursive handler installation: one key.
10. Rejections: growing-label recursion (ADR 007); `Grow`, the mutual pair
    and the data/effect cycle (section 4), with admissible variants.
11. `crash`: not caught by `handle`; reported once after cleanup;
    exit status 1; report lines for typed-abort-then-cleanup-failure and a
    non-printable payload.
12. Handler values: comparison, `print`, `crash` and a main result
    containing a handler are rejected, including nested in an ADT.
13. `ctx` mode: a pure `main` with an unused effectful function builds
    and runs.
14. Diagnostic quality (section 6): long call chains, nested callbacks,
    large rows, same-key mismatch and the side condition, asserting
    locations, related notes and bounded output.

**Acceptance scenario** (BACKLOG FX001): services with overlapping
requirements composed without annotations; real versus stateless fake
handler values injected at `main`; a missing-capability diagnostic meeting
section 6 (origin, boundary and path notes) when a handler is dropped; the scenario's specialization key count equals its
effect-free baseline plus its effect keys (quantifies key and code growth).

**Oracle.** An independent reference interpreter in the test tree with a
target-neutral model of sections 2-3 (evidence context, targeted aborts,
block exits), so later JS/WASM/LLVM backends can run the same semantic
corpus. Differential runs compare Go's stdout, stderr report and exit
status against it (extending FN001's tooling). `bootstrap/*.go` stays
byte-identical (conditional runtime emission).

**Regression proofs** (isolated mutants, each caught): Leijen side
condition removed (test hits its timeout); clauses run in the inner
context; abort consumed by the nearest `handle` instead of its target;
cleanup in the exit-time context; cleanup drops the pending cause;
provenance dropped; row abbreviation disabled; closed
parameter rows opened; `ctx` emitted for effect-free programs; `ctx`
mode chosen by reachability from `main` (the unused-effectful-function
probe fails to build); layout edges omitted from the declaration graph.

**Scale, attributed separately** (serial phase; fixed bounds, tuned
workloads, T003): installation cost (repeated shallow installs); lookup
cost (one deep context built once, then a measured loop of operations, so
native stack limits do not dominate); unwinding cost (a `fail` across N
frames, separately from 100,000 caught failures); `go build` of the
acceptance scenario.

**Documents.** ADR 010 (effects); docs/language.md section; BACKLOG: FN002
absorbed; new FX002 (concurrency), FX003 (local state), FX004 (general
resume and CPS confinement), FX005 (`ctx` elimination, cached lookup);
user Console handlers with D001; value-level error sums with R001; the
Result-to-failure limitation with STD001; I001 callback boundary; PKG001
export calling convention.

Nothing here is demonstrated: these are design obligations until the
implementation and measurements exist.

## 6. Diagnostic quality (user requirement 2026-10-09; acceptance, not polish)

Effect errors arise far from where they are reported: an operation deep in
a call chain or inside a callback is rejected at a signature, a `with
pure` parameter, a handler or `main`. FX001 diagnostics must explain that
path. No separate milestone; these are FX001 design and acceptance
requirements.

**Diagnostic model.** Today a diagnostic is `{ problem, span }` (one
location). FX001 adds structured related notes: `{ problem, span, related
∷ Array Note }`, each note a span plus a reason ADT (not a string),
rendered by Format.Diagnostic and carried on the wire as a `related` list.
Existing diagnostics have no notes and keep their exact text and spans
(their exact-text tests are unchanged).

**Provenance.** Every label that enters a row by consumption records its
origin: the consuming expression's span and what was consumed (operation,
call of a named function, application of a local or function value,
`fail` of payload type T). When a label crosses a boundary (a callback or
function value passed to a parameter, a handler installation, a call whose
ambient or named row carries it), the link to that boundary is kept, so
the path from origin to rejection can be reconstructed at report time.
Provenance is bounded: the first origin per scoped label *occurrence* is
kept, not per effect key, so nested `State(Int)` and `State(Bool)`, or
repeated entries of one `Fail` family, never inherit each other's
provenance; matching and diagnostic attribution use the same first-
occurrence distinction as unification (section 2). Chains are links to
declarations and spans resolved when reporting, never lists grown during
checking. Provenance never influences typing.

**Report shape.**
1. The headline is the row difference first: `Unhandled Database`,
   `Expected pure, found Log`, `Expected State(Bool), found State(Int)`.
2. The primary span is the expression, in the rejecting declaration's
   body, through which the constraint arrives (the actionable call).
3. Notes identify the rejecting boundary (the signature's `with`, or the
   signature when its row is ambient; the `with pure` parameter
   annotation; the `with` installation; `main`) and the originating
   operation, call or `fail`, with the intermediate call path between.

**Distinguished kinds.** Each has its own problem and message, never one
generic row mismatch:
- missing handler or capability (E_EFFECT): `Unhandled Database in main`,
  `Unhandled fail(DbError) in main`, `stamp performs Database, which its
  signature does not allow`;
- same-key payload mismatch (E_TYPE), naming the scoped first-occurrence
  rule: `Expected State(Bool), found State(Int)` with a note at the
  innermost `State(Int)` (its handler installation or signature entry);
- callback purity (E_EFFECT): `This function must be pure, but it
  performs Log`, at the argument, with notes at the `with pure`
  annotation and at the operation inside the callback;
- the scoped-labels side condition: `Clock + ...r and Log + ...r cannot be
  made equal: both end in ...r`.

**Abbreviation without losing relationships.** Differing labels print
first, always with their effect name and the mismatch; their type
arguments are abbreviated like any type when they are large: subterms off
the path to the differing subterm are elided (`State(Pair(…, List(Bool)))`
against `State(Pair(…, List(Int)))`), so the character bound holds
without hiding the effect or the relevant difference. Other labels are elided past a fixed count (`Database +
Log + Clock + … 9 more + ...e`). Tails and named row variables are always
printed, with the same name on both sides of a comparison, so shared-tail
relationships stay visible. Same-key duplicates are never merged
(multiplicity shows). Types inside labels use E011's elision once it
exists. Call paths print their first and last hops with `… k more calls`
between. Each diagnostic has fixed bounds on note count, path lines and
total characters (named constants chosen in the plan).

**Regression cases** (section 5 probe 14). Each asserts code, primary span,
related spans and note texts, and bounded output, not just error codes:
- a long call chain: Database required 30 calls deep and missing at
  `main` (exact elided path, origin and boundary notes);
- nested callbacks: an operation inside a lambda passed through three
  higher-order functions into a `with pure` parameter;
- large rows: a 50-label row missing one label (headline names only that
  label; shared tail kept; output within its bound);
- same-key payload mismatch under nested `State` handlers;
- the side-condition failure.
Mutants: provenance dropped (origin note missing) and abbreviation
disabled (bound exceeded), each caught.

**Research.** PureScript's row and effect diagnostics (as experienced in
MileAhead) are recorded as LA001 research cases
(docs/plans/2026-10-08-language-audit-plan.md), to check these rules
against concrete failures.

## Awaiting confirmation

Nothing. The defect-report format, scoped-occurrence provenance and
type-argument abbreviation were settled by the user on 2026-10-09; the
spec is approved for implementation planning.

## Deferred (not FX001)

Operation-level polymorphism (except Console's `print`); row parameters on
effects; general resume (`ctl`, FX004); concurrency (FX002); mutable state
(FX003); user Console handlers (with D001); value-level open error sums
(with R001); refutable `let`; let-generalization; explicit effect-row
constraint syntax; catching defects.
