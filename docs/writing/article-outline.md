# Building the Language I Want to Program In—with AI

Draft outline, revised 2026-10-10. Planned as a three-part series.

Markers:
- **[VERIFY]**: check a citation or claim before publishing.
- **[CODE]**: use a real, compiling Waxwing program.
- **[ILLUSTRATIVE]**: provisional syntax, to be labeled as such in the text.

Series thesis: precise contracts should stay affordable as an application
grows. Dependencies and failures are one composition problem. Waxwing tests
whether a language can make both ordinary. AI makes building it feasible.
Specifications, architectural boundaries and independent feedback keep that
work accountable.

---

## Part 1 — One composition problem, two faces

1. Open with code, not a list of preferences
   - A short scenario that recurs through the series:
     - load a user, record an audit event, return a domain result;
     - it needs a database and a logger;
     - it can fail with a database error or a domain error.
   - Show the contract I want to read off its signature:
     - what it needs;
     - how it can fail;
     - what remains once a caller supplies or handles some of that.
   - [CODE] Waxwing version, kept to services and failures. Records and
     classes don't exist yet.

2. The symmetry
   - A computation requires dependencies and may produce failures.
   - Composition combines both.
   - Supplying a dependency removes that requirement.
     - It may add the implementation's own requirements.
   - Handling a failure removes that possibility.
     - It may add the recovery's own requirements.
   - Unrelated requirements pass through untouched.
   - Core claim: requirements should compose, and discharging them should
     make what remains smaller.

3. First face: precise failures are expensive to compose
   - Independently defined error types don't combine into an anonymous
     union.
   - Nested sums bring injection and conversion plumbing.
   - A shared application error type connects everything, but it claims
     failures a particular function can't produce.
   - Cleverer encodings improve composition at a cost to decomposition or
     inference.
   - Parsons, *The Trouble with Typed Errors*, states the goals:
     - order independence;
     - little boilerplate;
     - easy composition;
     - easy decomposition.
     - [VERIFY] Say exactly what his later correction was, or drop the
       mention.
   - This isn't only Haskell's problem.
     - Rust has it too: `?` with `From`, `thiserror` and `anyhow`.
     - Name that here so Rust readers don't have to.

4. The tempting escape: move failure into `IO`
   - Haskell's extensible, dynamically typed exception hierarchy.
     - [VERIFY] Marlow 2006.
   - Selective catching is convenient.
   - But `IO a` no longer says which expected failures can escape.
   - Practical reasons for exceptions exist: interoperability and runtime
     concerns.
   - A workaround being familiar doesn't make its tradeoff desirable.
     - Show the cost in about ten lines of code rather than arguing it.
   - This is a criticism of the tradeoff, not of every Haskell programmer.

5. The precedent everyone will raise: Java's checked exceptions
   - They were the same goal: failures in signatures.
   - They failed largely because they couldn't be polymorphic over what a
     callback throws (lambdas, streams).
   - Effect-row polymorphism is the standard answer.
   - Set up Part 3: Waxwing meets the same tension again in `defer`.

6. Second face: dependencies and layered fulfillment
   - Small requirements compose:
     - one operation needs a database;
     - another needs a logger;
     - their composition needs both;
     - a caller with more can still supply what's needed.
   - Implementations bring their own requirements:
     - a repository implemented with a database and a logger;
     - supplying it discharges the repository requirement and exposes the
       database and logger requirements;
     - tests substitute an implementation with different requirements.
   - Haskell can express all of this:
     - records of functions;
     - `ReaderT` and `Has` (RIO);
     - `mtl`;
     - effect libraries (fused-effects and others).
   - My objection is the architecture burden.
     - You commit early to one encoding.
     - That choice shapes signatures, instances, tests and integration.
     - Libraries built on different encodings need adapting to each other.
     - [VERIFY] Cite the recurring debate (Snoyman's ReaderT pattern post,
       for example) or cut the claim.
   - I wanted the language to settle more of the foundation.

7. What TypeScript taught me about the experience
   - Structural compatibility: larger environments satisfy smaller
     interfaces.
   - Unions combine alternatives without wrapper constructors.
   - Narrowing recovers precision inside branches.
   - Effect carries the same ideas across whole computations:
     - success, error and requirement channels;
     - handling a tagged error removes it.
     - [VERIFY] Effect v4 documentation URLs.
   - Be precise about mechanisms.
     - Structural subtyping, union narrowing and row polymorphism are
       different tools.
     - TypeScript itself tracks neither thrown exceptions nor service
       requirements.

8. Why not an existing language?
   - PureScript with `purescript-variant` and `purescript-run` already
     gives open error rows and row-typed effects.
     - I write the compiler in PureScript, so answer this directly:
       - library encoding versus language facility;
       - inference and diagnostics;
       - runtime cost;
       - ecosystem and target.
   - Koka, Effekt, Unison, Flix, OCaml 5: one paragraph.
     - What they already prove.
     - What Waxwing combines differently:
       - row-polymorphic records together with effect rows;
       - instances you select explicitly;
       - the complexity budget;
       - the everyday experience.
   - No claim of global novelty.
     - The experiment is the combination, the restrictions, the syntax and
       the day-to-day feel.
   - Part 1 closes on the hypothesis:
     - make this composition ordinary;
     - keep contracts precise without a bespoke architecture per
       application;
     - prove it with real programs before claiming success.

---

## Part 2 — The language Waxwing is trying to be

Scope note for this part: the language means its frontend, syntax and type
system. The Go target is an implementation vehicle, the least important
part. Judge capabilities at the language level.

1. Influences, as a table rather than a list

   | Source | What Waxwing takes | What it doesn't take |
   |---|---|---|
   | PureScript | Row-polymorphic records; HKTs | Library-level effect encodings |
   | Koka | Effect rows; handlers; scoped labels | General control (for now; see 3) |
   | Haskell | ADTs; parametricity; classes with laws | Required newtype wrappers for instance choice |
   | Rust | Exhaustiveness; explicit failures; diagnostics; tooling | Ownership and borrowing |
   | fp-ts | Instances you choose and pass explicitly | — |
   | TypeScript | The experience: structural fit, unions, narrowing | Unsound escape hatches |

   - Address coherence here, not only in Part 3.
     - Haskell's wrappers exist because of the `Set`/`Map` ordering
       problem.
     - Instance-sensitive collections need an account of which instance
       they were built with.

2. The application experience, using the recurring scenario
   - Compose two operations: their dependencies and failure families both
     show in the type. [CODE]
   - Errors combine as several `Fail(E)` labels in one effect row, not as
     union types. Explain this mechanism; it's Waxwing's answer to Parsons.
   - Wrap with logging or timing. Clauses run in the outer context, so a
     handler can intercept and forward, and the wrapper leaves the other
     requirements alone. [CODE]
   - Supply implementations at a boundary. [CODE]
     - `Handler(L with R)`: installing the handler adds the clauses' own
       requirements to the surrounding row.
     - That is layered fulfillment, and it already works.
   - Handle an expected failure. `handle` removes that family; unrelated
     failures pass through. [CODE]
   - Add context only when it means something. A domain operation may
     deliberately translate a low-level failure.
   - Records and classes come later. Label those parts [ILLUSTRATIVE].

3. Effects: what the handlers can do, today and planned
   - The typing is Koka's: rows, polymorphism, scoped labels.
   - Handler semantics are currently restricted:
     - clauses resume immediately;
     - aborts are typed and targeted.
     - Today's expressive power is scoped service injection plus typed
       exceptions.
   - Planned: general resume (`ctl`, FX006).
     - Generators, coroutines and user schedulers.
     - Resume at most once by default, as OCaml 5 chose. [VERIFY]
     - Multi-shot (resuming more than once) is kept open as an opt-in that
       shows in the row.
   - Concurrency comes from runtime-backed structured concurrency (a
     reviewed design, `par let`), not from continuations.
   - Honest comparison with Koka, at the language level:
     - The only likely gap is multi-shot: search, backtracking,
       probabilistic handlers, exhaustive test exploration.
     - Workarounds without it: replay handlers, or explicit monads.
     - Implementation choices and FFI boundaries are not language gaps.

4. The complexity budget
   - Sophisticated theory in service of simple application code:
     - familiar syntax;
     - strict evaluation;
     - direct-style effects;
     - inference that keeps relationships across higher-order functions.
   - Prioritized: HKTs, explicitly selected instances, record rows, effects
     and handlers.
   - Deferred until a real need: higher-ranked types, GADTs, type families,
     general continuation control.
   - Boundaries:
     - some service APIs may eventually need higher-ranked operations;
     - restrictions keep checking and lowering tractable but exclude useful
       programs;
     - Part 3's `defer` story is a concrete example of that cost.
   - Usability is part of the budget:
     - readable inferred types;
     - missing-capability errors;
     - notes on where an effect came from (implemented);
     - bounded diagnostic output;
     - familiar library names.

---

## Part 3 — Building it with AI, and keeping it honest

1. The compiler's history in working slices
   - Each slice gets the same shape: desired behavior, design decision,
     boundary, evidence, limitation.
   - The slices:
     1. A minimal language: integers, booleans, calls, addition,
        conditionals. It runs end to end: parse, resolve, check, lower,
        emit Go, execute.
     2. Closed ADTs and exhaustive nested matching. Coverage is challenged
        by a brute-force oracle with inhabitedness checks.
     3. An applicative parser: input threading in one place, a structured
        diagnostic for excessive nesting.
     4. Rank-1 polymorphism with a separate specialization phase, and
        restrictions that keep specialization finite.
     5. First-class functions: closures, staged partial application,
        specified evaluation order.
     6. Synchronous effects: rows, first-class handlers, typed failures,
        cleanup, defect reports, diagnostic provenance.
   - State the timeline plainly. [VERIFY] Take dates from docs/progress.md;
     the milestones span days, not months.
   - Renaming (Sprig, then Bumpus, then Waxwing): one sentence.

2. Practical implementation choices
   - Written in PureScript; emits ordinary Go.
     - Go gets executable programs early, and is relevant to my work.
   - Distinct representations: parsed, resolved, checked polymorphic IR,
     monomorphic IR, Go.
   - Enforced boundaries:
     - pure transformations;
     - effects only in the host layers;
     - only certain modules may construct each IR;
     - structured diagnostics.
   - One consequential choice: effect rows are erased before
     specialization, and handlers are passed at runtime.
     - Static tracking and runtime representation solve different problems.
   - Still hard:
     - code growth;
     - FFI;
     - runtime representation;
     - resources;
     - other targets.

3. What AI changes about the work
   - Feasibility at a scale I couldn't otherwise sustain.
   - Compiler phases make good delegation boundaries:
     - explicit inputs and outputs;
     - established literature;
     - precisely testable behavior.
   - My role:
     - decide what the language promises;
     - compare approaches;
     - choose restrictions;
     - ask what evidence could falsify an implementation;
     - decide when something is ready to build on.
   - Durable instructions and skills:
     - planning and review procedures;
     - architecture and style rules;
     - recorded findings and handoffs;
     - small tasks with acceptance conditions.
   - Model allocation: cheaper models implement, stronger models design
     and review adversarially.
     - Model choice is an operational decision, not evidence of
       correctness.
   - "Vibe coding" undersells this. Describe the process instead of
     arguing about the label.

4. Case study: "`defer` must not fail" (verified version)
   - The guarantee:
     - deferred cleanup can't end in a typed abort;
     - cleanup may still perform other effects.
   - My decision, after Swift's `defer`:
     - a static rule rather than converting the abort into a defect at
       runtime.
   - The plausible first implementation checked only the labels written in
     the deferred expression.
   - How it was found: an AI reviewer constructed probe programs. There
     was no reference interpreter involved.
   - The counterexamples were five accepted programs:
     - callback parameters with ambient or named rows;
     - closures whose rows weren't settled yet;
     - lambdas decided later.
     - In each, a typed failure escaped cleanup and became a fatal defect.
   - The AI implementer's own tests passed 25/25 against the unsound check.
     - This is the clearest example of implementation and tests sharing a
       misunderstanding.
   - The repair (d5bfa8d): the deferred expression gets its own row, judged
     after constraints settle.
   - The cost, which is my choice: the bracket idiom needs `with pure`
     callbacks.
     - The precise alternative is a lacks-`Fail` constraint (FX007, open).
     - Tie back to Part 1: this is Java's checked-exception problem
       reappearing.
   - Lessons:
     - precise specifications make failures discoverable;
     - AI speeds up production of plausible mistakes as well as fixes;
     - review is valuable when it produces concrete counterexamples.

5. Second act: handler clauses (FX008, confirmed; repair designed, not
   implemented)
   - The hole:
     - a failing `Log` handler, installed anywhere up the stack, makes
       `defer log(1)` end in a typed abort;
     - the deferred row shows only `Log`.
   - How it was found: by the reference interpreter of FX001 Task 10
     (50f84ae), an independent model in the test tree, not a reviewer's
     probe. It reported "typed abort escaped cleanup" on a generated
     program. The Task 10 reviewer then confirmed with the compiler that
     the program is accepted.
     - Analysis then showed the handler need not be local. Any caller can
       install it, so no check of the deferred expression can establish
       the rule.
     - The Task 8 review had concluded that clauses reach the deferred row
       only through metas or rigid tails; this case uses neither.
   - Confirmed behaviour today (BACKLOG FX008):
     - the lexical and cross-function forms are accepted;
     - with no pending abort, the cleanup's `fail(E)` skips the enclosing
       `handle` and the program exits 1 with `fail(E): E`;
     - with a pending `fail(F)`, F never reaches its `handle`, and the
       report reads `fail(F): F`, then `cleanup failed: fail(E): E`.
   - My decision: keep the language's structure, with no runtime delivery
     or conversion, and fix it in the types.
     - A `nofail` mark on effect labels.
     - Each installation computes whether its handler frame can abort.
     - Signatures write `nofail L` to rely on it.
     - Design: docs/plans/2026-10-10-abort-tracking-design.md, revision 10,
       approved 2026-10-10. Decisions D0-D7 are in its §11.
   - What review found (records in docs/sdd/2026-10-09-effects-plan/):
     - Termination problems, repeatedly. Each was a non-terminating
       procedure, not a wrong answer:
       - late consumption looping on a shared tail (N1,
         rereview-fx008-design-result.md; revisions 2-3, afedaec);
       - a hang on duplicate labels and a dropped rigid tail (P3/P4 and T1,
         review-fx008-termination-result.md; revision 5, 9b47e4b);
       - the one-way hook diverging on cycles
         (review-fx008-rev8-hook-result.md, c6fcbda);
       - a self-renaming loop (review-fx008-rev9-f1f2-result.md, 4539150).
     - Rejections of previously accepted programs:
       - some intended: the unsound programs themselves, plus one test
         migrated to `with nofail Log`;
       - several unintended, each caught by review before any code and
         corrected:
         - lost inference through the handler row (meta2/hole2c,
           review-fx008-rev6-result.md, 39357dd);
         - late labels (late1/late2, review-fx008-rev7-result.md,
           b1126ac);
         - two handlers sharing a lambda (review-fx008-rev8-hook-result.md);
         - over-restored equalities and a timing-dependent link (ov1, set1;
           review-fx008-rev9-f1f2-result.md).
       - The final re-check found no substantive issue
         (review-fx008-rev10-result.md).
     - Along the way, review exposed a soundness bug in the shipped
       checker (FX009: a `Fail(a)` parameter row let a failure escape at
       run time). It was fixed, reviewed and merged (26fefe3).
   - Repair status at the time of writing: design approved, implementation
     plan being written, nothing implemented. The plan starts with a probe
     gate that pins every review probe's outcome today.
   - [VERIFY] Update the repair status at publication.
   - Lesson for the article: a reference interpreter found what probe-based
     review had missed. Adversarial review of the *repair* mostly found
     termination and compatibility failures, not soundness failures.

6. Feedback loops
   - Real Go is compiled and executed; output is deterministic.
   - Independent models:
     - reference interpreters for earlier milestones;
     - a brute-force coverage oracle;
     - union-find and row-unification oracles;
     - generated programs.
   - Structural properties:
     - roundtrips;
     - exact diagnostic codes and spans;
     - phase and import boundaries.
   - Regression proofs: restore each defect in an isolated copy and show
     the test fails.
   - Adversarial review: ask for counterexamples, termination problems and
     edge cases.
   - Keep claims proportionate.
     - Test counts measure activity.
     - Regression proofs are not soundness proofs.
     - AI-written code and AI-written tests can share a misunderstanding.

7. Limits and status at publication
   - I'm learning compiler implementation by building a compiler.
     - AI widens what I can attempt.
     - It also makes it more important to notice what I don't understand.
   - Theory supplies foundations. It doesn't prove this combination or
     this implementation sound.
   - Runtime details remain part of language design:
     - allocation;
     - continuations;
     - foreign boundaries;
     - scheduling.
   - Implemented:
     - core compiler;
     - ADTs and exhaustive matching;
     - rank-1 polymorphism;
     - first-class functions;
     - effects through FX001 Task 9 of 12.
   - Designed but not authorized: structured concurrency (CF001).
   - Planned:
     - HKTs and kinds;
     - classes and selected instances;
     - record rows;
     - general resume;
     - modules;
     - schemas.
   - Not claimed:
     - novelty;
     - production readiness;
     - an end-to-end demonstration of the application experience.

8. Next foundations (keep it short)
   - Modules and abstract types, judged against what functions, records,
     classes and handlers already provide.
   - Selectable instances with predictable selection.
   - First-party schemas: parse into trusted domain values, structured
     errors, derived generators and shrinkers.
   - Concurrency: structured lifetimes, sharing boundaries, cancellation.
     - Effect labels alone don't prove race or deadlock freedom.

9. The experiment I actually want to run
   - Questions:
     - Do dependencies compose without plumbing?
     - Do failures stay precise as they are combined and handled?
     - Do the abstractions stay approachable?
     - Do the diagnostics explain the programmer's problem?
     - Does the implementation stay tractable?
   - The next persuasive evidence is a representative application:
     - a domain model;
     - boundary parsing;
     - several services;
     - expected failures and recovery;
     - test implementations;
     - cleanup.
   - Closing: "AI lets me explore language design through a working
     compiler. The work is deciding what that language should promise—and
     finding out whether I can keep those promises."
