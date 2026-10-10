# Waxwing / FX008: design approved; implementation plan next (2026-10-10)

Branch fx008 (local). FX009 is fixed and merged (26fefe3; verify green:
958/958, 29/29, 36 proofs). The FX008 design note
docs/plans/2026-10-10-abort-tracking-design.md is at revision 10 and was
approved by the user on 2026-10-10, after focused reviews of the one-way
hook's procedure (review-fx008-rev9-f1f2-result.md,
review-fx008-rev10-result.md). The user's decisions D0-D7 are in §11.

Next: the implementation plan (superpowers writing-plans). Its first task
is the probe gate: the probes in .build/fx008-probes/ and its rev6-rev10
subdirectories go into the test tree, each recorded with today's outcome.
Then test-first implementation, then FX001 Tasks 11-12. Open rows: FX010,
FX011, FX012. Nothing of FX008 is implemented.

# Waxwing / FX001: Task 10 done; FX008 design next (2026-10-10)

Branch claude/vibrant-cerf-3km61i = main (PR Ethan826/waxwing#1, Tasks 1-9)
+ Task 10 (reference interpreter, generator, 500-program differential
corpus with 0 differences; test-side only) + docs. FX001 Tasks 1-10 are
complete and reviewed; Tasks 11-12 are amended in the plan (rulings
R1-R12) and not started. Work continues on the user's machine.

Next, before Tasks 11-12: FX008 (BACKLOG), a soundness hole in the strict
`defer must not fail` rule. Cleanup may perform an operation whose handler
clause fails — the handler may be installed by a caller in another
function — so a typed abort can end a cleanup (pinned in
test/fx-oracle.test.mjs). User decisions 2026-10-10: do not weaken the
language's structure or design (no runtime delivery or conversion of such
aborts); fix by type-level tracking: performing L under a handler whose
clauses may fail may abort, carried through rows and across calls. Write a
design note (spec §2/§3 change), get it reviewed, decide with the user,
then implement test-first; afterwards lift Task 10's generator restriction
(fail-free random clauses).

Awaiting the user's review:
- CF001 concurrency foundations, docs/plans/2026-10-09-concurrency-
  foundations-design.md: recommended fork-join subset (`par let`),
  R0 "performs no X" rule, task-boundary rules, failure selection, discard
  contract, and the 2026-10-10 operational addendum (§8A: supervision vs
  structured concurrency, defect boundaries, state ownership, overload,
  observability, host boundaries, tooling) with decisions O-1..O-7. Four
  Opus review rounds plus addendum reviews; not authorized for
  implementation.
- BK001 Go backend maintainability, docs/plans/2026-10-10-backend-syntax-
  proposal.md: Tier 1 (total plan records, Signature/Callee by call kind,
  Go-correct quoting, Lines/Inline helpers) after FX001; migration steps
  0, 1, 6 before FX005/FX002 lowering. Not authorized.
- FX007: strict `defer must not fail` (adopted 2026-10-09; bracket idiom
  needs `with pure` callbacks) vs a future lacks-Fail constraint.
- Task 12 ADR 010 wording additions from CF001 §10/§8A (cause kinds an
  open set; report and exit 1 are main's root policy; Go fatal errors are
  Go's behaviour, not a Waxwing guarantee; `cleanup failed:` means a cause
  raised by cleanup).

Execution: superpowers subagent-driven-development (skills linked under
.claude/skills): Sonnet implementers, Opus reviews; Haiku/Sonnet for
mechanical edits and small re-reviews. Ledger and every brief/report/review
are snapshotted in docs/sdd/2026-10-09-effects-plan/ (the live workspace
.superpowers/sdd/ is git-ignored).

Cloud environment notes: run `NODE_USE_ENV_PROXY=1 npm run build` once to
fill .spago (not during verify). Use `GOTOOLCHAIN=go1.26.4`. On this
container fixed timing bounds fail at unchanged baselines (BACKLOG T007,
T004); per ruling R1 a verify passes when only those fail and
`node scripts/regression.mjs` exits 0. Never relax a bound. The container
restarted twice during this session; work in flight was recovered or
re-dispatched.

# FN001 merged into main

Workspace: /Users/ethan/Desktop/gofuncyourself, branch main (FN001 merged
2026-10-09 and pushed to origin/main; P001 at dcb40fb). Read AGENTS.md,
README.md, docs/adr/008-functions.md (FN001), ADRs 001-007,
docs/plans/bootstrap.md, docs/progress.md, docs/findings.md,
docs/engineering.md and BACKLOG.md. The uncommitted .vscode/settings.json
change predates this work.

State: first-class functions, lambdas, closures, staged partial and
over-application and `|>` are implemented (ADR 008; design and plan
docs/plans/2026-10-08-functions-{design,plan}.md). `rm -rf output && npm
run verify` exits 0 on the merged tree: 541 parallel tests, 12 serial
tests (`test/*.serial.test.mjs`), twenty-two regression proofs
(.build/fn001-merge-verify.log). Tools: scripts/differential.mjs
(compare two compiler builds), scripts/fn-milestone.mjs (20,000-parameter
tier, not in verify), scripts/ladder-profile.mjs, scripts/stage-probe.mjs,
`node scripts/regression.mjs name…`.

Update 2026-10-09: the user chose FX001. Its written spec,
docs/plans/2026-10-09-effects-design.md, was settled section by section
with the user; the whole-spec review is applied (fd625a4) and §6
diagnostic quality was added at the user's request (provenance, row
difference first, origin/boundary/path notes, distinguished missing-
handler, same-key mismatch and callback-purity errors, bounded
abbreviation, regression cases; PureScript research cases in LA001).
The spec is approved; the implementation plan
docs/plans/2026-10-09-effects-plan.md (12 tasks) was revised after the
user's review and execution is authorized: subagent-driven (fresh
implementer and reviewer per task, whole-branch review), branch fx001 in
.worktrees/fx001; stop and report if Task 1 rejects a runtime shape.

Earlier next steps (before FX001 was chosen): none authorized. Candidates, for the user to choose: C001
and R001 (review jointly; decide whether instances are ordinary records),
FX001, FN001 follow-ups FN002-FN006, and the open timing/scale items
T002-T005, G002, G003.

Long-term discussion is recorded in plans/2026-10-08-language-direction.md:
row/service architecture, explicit effects design (FX001), inspectable
lowered IR (L001), and future target evaluation (J001). These do not
authorize new implementation.

The same direction document records proposed `do` notation under FX001:
bind/lambda elaboration, result bindings and discarded results, final
computation, deferred execution, and inferred service/error requirements.
Syntax, bind/pure selection and monadic versus algebraic effects remain
open; this records discussion without authorizing implementation.

Further discussion favors evaluating Koka-inspired direct-style effects
and familiar `+`/named spread notation (`Log + ...effects`). See the
direction document's open-row section for inference and proposed implicit
universal quantification. Explicit effect-row constraint syntax is a
future feature outside initial FX001; keep record-row constraints separate.

Language-direction now also captures MileAhead's open error-row pattern
from read-only ../trailmapper: family rows compose without wrappers, stay
open until handling, and wrap only to add context. Candidate Waxwing error
sums hide `Variant`/injection plumbing. FX001/R001 must resolve the open
error-sum need against R001's deferred general variants before changing scope.

STD001 records the user's common-FP-helper requirement and approachable
naming direction, informed by Rust. Read
docs/plans/2026-10-08-standard-library-direction.md: inventory, candidate
names (getOrElse, mapOrElse, matchWith, joinWith), eager/lazy distinctions,
coverage acceptance and staged prerequisites. No helpers added to FN001.
User clarification: naming convenience must preserve lawful HKT-based
generic contracts. bimap works for any Bifunctor; optional values and
fixed-error Result share Functor/Applicative/Monad APIs. Read STD001's
generic-rigor section for constructor kinds, instance/evidence design,
user-defined-instance acceptance and law/coherence properties.

LA001 now plans the broader cross-language audit, beyond STD001's helper
coverage. Read docs/plans/2026-10-08-language-audit-plan.md: twelve required
references, source/version/section ledger, comparative briefs, feature and
interaction matrix, practical scenarios and independent review. Feed it
into upcoming type/row/effect designs without interrupting FN001; existing
advanced-feature deferrals remain. Source entry points checked, audit not run.

Tooling direction is recorded in plans/2026-10-08-tooling-direction.md:
IDE001 highlighting/editor support, DOC001 first-class doctests, PBT001
language-user generators/shrinking/replay and law suites, AI001 versioned
LLM skills/discovery, and exploratory LIT001 literate capabilities. Feed
these into LA001 and focused subsystem designs; no tooling implementation
is authorized or added to FN001. Existing compiler properties do not
complete PBT001. Preserve the tentative status of literate capabilities.
PKG001 extends that direction with portable Waxwing libraries, host FFI,
service implementations/fakes and package management over both Waxwing and
host dependencies. Review exports, source/type identity, target/runtime
support, manifests/locks and host resolver integration with M001/I001/FX001.
Effect Platform is conceptual influence; no package manager, ABI or provider
mechanism is selected and no publication is authorized.

Open items: E002 remainder, E006-E011 (P001 follow-ups: stack margin,
exponential type size, Expand keys, lowercase-type hint, mismatch `_`,
near-limit elision), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005; design follow-ups FX001, L001, J001 and D001.
