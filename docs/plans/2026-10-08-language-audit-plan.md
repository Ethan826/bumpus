# Cross-language design audit (LA001)

Recorded 2026-10-08 at the user's request. Status: planned research/review,
not an executed audit or authorization to implement features. STD001's
helper inventory is narrower; this audit covers language, library and
runtime design. Source landing pages have been checked, not fully reviewed.

**Goal:** establish a coherent, practically sufficient FP language feature
set with defensible semantics, explicit omissions and source-backed
decisions. Avoid both accidental gaps and feature accumulation for its
own sake. Preserve lawful generic abstractions and approachable APIs.

**Method:** read primary specifications, reports, reference manuals,
maintainer guides and API/law documentation; write independent comparative
notes. A tutorial/précis is an entry point, not evidence for a disputed
semantic claim. Distinguish languages from libraries and runtimes, and
standard features from implementation-specific extensions.

## Source roster and initial reading focus

Pin editions/releases or repository revisions in Task 1; moving URLs below
are discovery links, not a versioned evidence ledger.

| Reference | Primary starting points | Initial review focus |
|---|---|---|
| Koka | [Book](https://koka-lang.github.io/koka/doc/book.html), linked language specification and handler compilation papers | Effect inference, rows, handler/resumption semantics, higher-order effect propagation, lowering |
| Haskell | [2010 Report](https://www.haskell.org/onlinereport/haskell2010/), [GHC extensions guide](https://downloads.haskell.org/ghc/latest/docs/users_guide/exts.html), base API | Generic abstractions/laws, inference, constraints, patterns, modules, strictness and evaluation boundaries; distinguish GHC extensions |
| PureScript | [Language reference](https://github.com/purescript/documentation/tree/master/language), [Pursuit](https://pursuit.purescript.org/) | Records/error rows, kinds/HKTs, classes/evidence, strict FP, standard helpers, foreign boundaries |
| Rust | [Reference](https://doc.rust-lang.org/reference/), [standard library](https://doc.rust-lang.org/std/) | Results/options, exhaustive patterns, modules, diagnostics/tooling, practical APIs, ownership/resource alternatives |
| OCaml | [5.5 manual](https://ocaml.org/manual/5.5/index.html) | Curried multi-argument calls, inference/generalization, variants, modules, abstract types, effects |
| ZIO | [Reference](https://zio.dev/reference/) | Environment/error/result composition, provision, resources, cancellation, concurrency, testing |
| Effect (TS) | [Maintainer docs](https://effect.website/docs/), versioned API/source as needed | Typed service/error composition, runtime defects, resources, cancellation, scheduling, schema/ingress boundaries |
| fp-ts | [Guides and APIs](https://gcanti.github.io/fp-ts/) | Generic HKT interfaces/laws, data-last composition, RTE, widening, helper coverage and naming |
| Scala | [Scala 3 reference](https://docs.scala-lang.org/scala3/reference/overview.html), versioned standard APIs | Type constructors, contextual evidence, explicit instance alternatives, extension APIs, opaque types, unions and modules |
| Elm | [Maintainer guide](https://guide.elm-lang.org/), official core APIs | Small coherent surface, diagnostics, records, commands/subscriptions, web architecture and practical data helpers |
| Idris | [Idris 2 docs](https://idris2.readthedocs.io/en/latest/), versioned reference and Prelude | Interfaces, totality, diagnostics and refined-data lessons; record advanced mechanisms without adopting dependent types/indexed monads |
| Clojure | [Reader reference](https://clojure.org/reference/reader), linked language/reference sections and core API | Persistent collections, sequence/transducer APIs, protocol/interop design, data-oriented ergonomics |

All twelve are required roster entries. Add other references only to answer
a documented gap/question, with an explicit scope note; do not let "etc."
turn the audit into an unbounded bibliography.

## Common comparison axes

1. Values, evaluation order, strictness/laziness, closures, currying,
   local bindings, recursion, termination and stack safety.
2. Type/kind inference, annotations, HKTs, polymorphism/generalization,
   constraints, instance selection/coherence and abstraction boundaries.
3. ADTs, exhaustive patterns, records/open rows, error sums, refinements,
   numeric/text semantics and persistent collections.
4. Effects: requirement tracking, provision, construction versus execution,
   normal/abortive/multiple resumptions, typed failures versus defects,
   resource cleanup, async/cancellation/concurrency and evaluation order.
5. Standard-library breadth, laws, reusable generic operations, naming,
   module organization and interoperability of the same abstractions.
6. Modules/imports, public interfaces, FFI validation, specialization,
   target-neutral IR, runtime layouts, backend constraints and code growth.
7. Diagnostics, documentation, formatting, editor support, testing,
   packaging and realistic full-stack/native application needs.

Use these axes for comparable briefs; mark absent/not applicable topics
explicitly. Bibliography size and matching feature names are not sufficient
evidence of coverage or semantic compatibility.

## Task 1: Freeze sources and Bumpus baseline

- [ ] Create docs/research/language-audit/sources.md with reference kind,
  edition/version/revision, exact sections/links, access date and reading
  status (unread, surveyed, deeply reviewed, unavailable).
- [ ] Record existing Bumpus behavior against tests/ADRs separately from
  approved designs, direction-only proposals and missing features.
- [ ] Index all relevant core/reference sections and record which are read,
  deferred as irrelevant, or blocked. Do not claim a whole spec was read
  when only a summary or selected chapters were inspected.

## Task 2: Read the roster and produce comparative briefs

- [ ] Produce one brief per reference under docs/research/language-audit/.
  Read relevant core chapters and pursue primary sources for detailed
  claims; update the section ledger and explain deliberate omissions.
- [ ] Each brief states the problem solved, precise semantics/laws,
  strengths, tradeoffs, rejected/invalid examples, user experience and
  relevance to Bumpus. Label source-backed facts versus our inferences.
- [ ] Reproduce small disputed examples with the source toolchain when
  feasible; record version/results or the inability to run them. A reading
  claim is not an execution claim. Reference projects remain read-only;
  no unlicensed implementation is copied.

## Task 3: Build the feature and interaction matrix

- [ ] Create docs/research/language-audit/matrix.md with feature/problem,
  primary evidence, user scenario, current Bumpus state, proposed decision
  (adopt/adapt/defer/reject), rationale, prerequisites, risks, backlog/ADR
  owner and a concrete future acceptance test/property.
- [ ] Reconcile with FN001, K001, C001/R001, FX001, M001, D001, STD001,
  I001 and L001/J001 rather than duplicating their tracking.
- [ ] Review interactions explicitly: currying versus effect timing;
  generic instances versus rank-1 records; rows versus specialization;
  open errors versus exhaustive handling; handlers versus resources and
  cancellation; total helper laws versus effectful callbacks; modules and
  FFI versus abstraction/validation boundaries.

## Task 4: Resolve concrete application scenarios

- [ ] Walk through lawful bimap on a user-defined bifunctor and generic
  mapping/chaining across optional values and fixed-error results.
- [ ] Walk through overlapping service requirements with real/fake
  substitution, missing-capability diagnostics and inferred effect rows.
- [ ] Walk through clock/UUID/database creation, MileAhead-style error
  widening, context-only wrapping, partial handling and exhaustive closure.
- [ ] Walk through cleanup on failure; propose async/cancellation scenarios
  only if FX001 scope includes them, otherwise mark them deferred.
- [ ] Walk through modules sharing pure domain code, safe foreign ingress,
  practical text/numbers/collections, and the proposed web/native targets.
  Sketches are not working demonstrations until independently tested.

## Task 5: Review and durable handoff

- [ ] Obtain an independent review of evidence, missing basics, incompatible
  semantics and unnecessary complexity; record resolved findings.
- [ ] Present a proposed early-release feature set and a deliberate
  omission list to the user. Resolve substantive scope decisions before
  updating implementation designs or marking them approved.
- [ ] Update affected ADRs/backlog/design docs with traceable decisions;
  leave unknowns as specific research items with a next action.

## Timing and completion gate

Keep FN001's approved delivery moving. Run this audit before settling the
shared K001/C001/R001/FX001 designs; feed each relevant subsystem brief into
its review and STD001's API coverage work. No design should claim audit
coverage before its relevant sources and interaction checks are reviewed.

LA001 is complete only with twelve reviewed briefs, a source/section ledger,
the decision matrix, interaction findings, independent review and durable
handoff. Survey completion does not authorize implementing every feature.
Higher-ranked types, GADTs/type families, dependent/indexed machinery and
explicit effect-row constraint syntax retain their existing deferrals.
Any revision requires its own reviewed scope decision. Existing verification
and evidence rules apply to changes; proposed features are not validated
by the current compiler suite.
