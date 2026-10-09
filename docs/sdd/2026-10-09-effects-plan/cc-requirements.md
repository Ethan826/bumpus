# User requirements for the concurrency-foundations design investigation (2026-10-09, verbatim)

Complete FX001 Task 8, then stop. Do not begin Task 9 or implement concurrency. Preserve the normal Task 8 review, verification, and durable handoff, reporting any failed checks accurately.
At the stopping point, document a proposed, bounded design milestone for concurrency foundations. The user wants to invest now where established CS theory could let types, effects, lawful type classes, and abstractions eliminate programmer-managed synchronization or simplify the runtime. This is a design investigation, not authorization to build a scheduler or add speculative language features.
Use a small set of primary research sources. Assess:

* Region/read-write effects and ownership or linear/affine capabilities for proving that parallel computations do not interfere.
* Applicative independence, commutative effects, and graded/indexed monads for expressing dependencies, resource access, and permitted composition. Ordinary monad or applicative laws alone do not establish safe parallel execution.
* Lawful abstractions for shared updates and reductions, including lattice-based deterministic parallelism such as LVars. Identify precisely which laws support each guarantee.
* How laws are established: compiler-enforced restrictions, proofs, trusted built-ins, or user obligations supported by tests. A type-class instance declaration must not be treated as proof.
* Structured concurrency, task-local state, and explicit shared-resource capabilities as possible boundaries that concentrate synchronization inside a small runtime.

Separate type/effect soundness, race freedom, determinism, deadlock freedom, and cancellation safety. For each proposed guarantee, explain its assumptions, what the compiler checks, what runtime machinery remains, and which programs it excludes. Recommend a small, defensible initial subset rather than trying to guarantee everything.
Ground this assessment in the shipped implementation:

1. Tasks 6–7 erase rows and use immutable evidence-context lists, dynamically selected handlers, and targeted stack-unwinding aborts. Immutable context nodes do not prove that handler resources are safe to share.
2. Define proposed task-boundary rules for handler inheritance, capability sharing or transfer, and child failures. A child cannot simply inherit a parent's abort marker and unwind the parent's stack.
3. `pure` currently permits divergence and `crash`. An empty effect row alone therefore does not justify arbitrary parallelization or reordering while preserving observable failure behavior. Specify the intended equivalence and failure-selection policy.
4. Task 8 forbids typed failures escaping deferred cleanup but permits defects. A pending typed abort reaches its handler only if cleanup completes without defects; otherwise it becomes part of the fatal report. Check documentation for overbroad promises.
5. Identify cancellation as a future task-exit reason. Propose rules for exactly-once cleanup, cancellation shielding, suspending cleanup, and continuation ownership. Keep multi-shot continuations containing cleanup explicitly unresolved.
6. Determine which resource/effect information must survive checking for future parallelism and suspension analysis. Row erasure may remain appropriate, but additional IR metadata or analysis may be necessary.

Deliver a concise recommendation and durable handoff covering:

* Decisions worth settling before concurrency, mutable state, or resumable handlers.
* Choices that can safely wait until runtime implementation.
* Necessary changes to the existing design, if any, with concrete motivating examples.
* A small core semantics and proof obligations for the recommended subset, clearly distinguishing proposed proofs from established results and implementation tests.

Do not undo Tasks 6–8 merely because stronger guarantees are possible. Explain whether their contracts can be extended and where a real incompatibility exists. Keep research and model usage bounded; use cheaper models for mechanical work and reserve stronger review for semantic decisions. Stop after Task 8 and this design handoff, pending the user's review.
