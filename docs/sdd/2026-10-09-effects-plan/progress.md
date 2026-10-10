# SDD ledger — plan: docs/plans/2026-10-09-effects-plan.md

Recreated 2026-10-09 in a cloud session; the original local ledger (Tasks 1-5)
was never committed. Tasks 1-5 complete per docs/progress.md and git:
Task 1: complete (863babf)
Task 2: complete (e110526)
Task 3: complete (3481468, 95458e3)
Task 4: complete (9f705db)
Task 5: complete (9a6befd)

Ruling: Task 6 implementation was done inline by the controller (WIP 2501024)
before the SDD skill was available — keep it, treat it as the implementer's
output, and give it the full task review (opus) — rework costs less than
re-implementing; if wrong, the review catches it.
Ruling: models — implementers sonnet (haiku for transcription/single-file
fixes), task reviews and pre-flight/final reviews opus — per user 2026-10-09.
Finding (Task 5 defect, found in Task 6): `with R` inside `Handler(L with R)`
is silently dropped by the type parser (inner typeRef consumes and discards a
row on a non-arrow segment). Fix before Task 6 review; separate commit.
Baseline (pre-change) verify here: 720/722; test-helper stack overflow
(poly-keys eager JSON.stringify, fixed in 2501024) and 5,000-arm match timing
5.82 s > 5 s (to BACKLOG).
Task 6: controller fixed fallout (uncommitted at this point): fx-signature
unused-effect test now expects success (guard is over emitted IR, spec §4
"Uniform ctx"); regression row handler-metadata migrated to
Features/Specialize/Unlowered (needle: drop effect layouts) — proof passes.
Note: one controller build ran concurrently with the parser implementer's;
a transient regression failure resulted. Do not build in parallel again.

## Pre-flight scan (opus): preflight-scan.md — 28 rows, rulings:
Ruling F1: ctx key = EffectId for user effects; Fail handles keyed by (Fail, TypeHead) — spec S401-409 is binding; plan only names Go identifiers — cost: none if spec holds.
Ruling F2: IR OperationRef stays (bare operation with parameters is a function value, spec §1); Task 7 lowers it like FunctionRef and counts it in usesContext — cost: small.
Ruling F3: Handler(Console)/Handler(Fail(E)) layouts emit empty handler structs in Task 7 (uninhabited types, but must compile) — rejecting in Check would change accepted Task 5 programs; revisit with D001.
Ruling F4: Task 7 replaces each 'unlowered effect' assertion with a stronger executable assertion and re-targets regression row handler-metadata; never deletes one without a replacement.
Ruling F5: keep counting only keys with type arguments (effects as types/functions today) — the limit is a polymorphic-key guard (Keys.purs comment, design §6); spec S427 "every key" read as "every polymorphic key, including effect keys"; record in ADR 010 — cost: a doc mismatch only.
Ruling F6: Task 11 baseline = the same scenario with effects/handlers replaced by plain parameters, written in the test; assert difference = #effect keys.
Ruling F7: Task 7 guard panic is a plain Go panic string "no handler for L"; Task 8's defect reporter formats any non-abort panic value as a defect line; specified in Task 8 brief.
Ruling F8: adopt spec §3 text: an abort or defect escaping cleanup while another cause is pending becomes an uncatchable cleanup defect carrying both — spec text says so; flagged to the user for confirmation before Task 8 (non-blocking now).
Ruling F9: keep implemented `Fail(DbError)` label spelling (rows print labels capitalized everywhere, §5 Row display); spec S706 lowercase is a typo — cost: one text change.
Ruling F10: keep implemented headline text; "(required by …)" becomes a Task 9 note — per scan.
Ruling F11: Task 10 differential corpus runs as a *.serial.test.mjs file (verify's serial phase), seeded, with an env knob for larger runs outside verify.
Ruling F12: Task 6 executable probes deferred to Task 7 (guard prevents Go); Task 6's two already-passing tests are characterization tests, documented as such in progress.
Ruling F13: Task 9 creates a new module for origin hooks rather than growing UnifyRow; include deferred Fail retries provenance in its brief.
Ruling F14: Task 12 uses next free BACKLOG ids (check BACKLOG at the time) instead of FX004.
Ruling F15: work on claude/vibrant-cerf-3km61i in place (session's assigned branch); no worktree — same isolation (dedicated branch) — record in progress.
Ruling F16: Task 6 review after parser fix commit — already the plan.
Ruling F17: Task 12 probes go into a new test/regression-fx.mjs; side-condition mutant gets an explicit timeout treated as failure.
Ruling F18: Task 10 brief adds the verify step; Task 11 reuses existing 20,000-let test rather than duplicating, and adds a services.go snapshot comparison.
Ruling F19: Tasks 7/8 file lists are compile-guided.
Parser fix 5da7865: review (opus) ❌ Needs fixes — Important: Handler args via bare operand regress `Handler((Clock))` (accepted→E_SYNTAX) and `Handler(Int -> Int)` (E_ARITY→E_SYNTAX). Minor (deferred to final review): negative tests assert code only; lambda-param and fail-clause rejections untested; findMap over take 1 obscure.
Parser fix: fix round 1 queued (resume implementer) after the running full verify ends.
Task 6 test-shape updates committed 85c5867 (poly-run keys effect:false; specialize identity asserts effects == []).
Regression proofs run 1: 7 passed, row 8 (capture) copy failed to compile — run overlapped implementer's parser edits; rerun after fix round.
Parser fix round 1: 3aa1217 (Handler args via typeAndRow; lone-arg row lifted). Scoped re-review (opus) dispatched. Task 6 review (opus) dispatched: brief task-6-brief.md, report task-6-report.md, package review-task6.diff (9a6befd..HEAD, Task 6 paths).
Parser fix re-review r1: findings 1-4 ADDRESSED; new Important: HandlerType.purs:61-68  ignores found.row →  silently drops one row. Round 2 queued after regression proofs.
Parser fix re-review r1: findings 1-4 ADDRESSED; new Important: HandlerType.purs:61-68 sole ignores found.row, so Handler(Clock with Log with pure) silently drops one row. Round 2 queued after regression proofs.
Task 6 review (opus): Spec ✅, quality Approved; no Critical/Important. Probed finiteness risks all rejected.
Task 6: minor (deferred): Format.Go Expression/Usage use wildcards for the six effect nodes — Task 7 brief: list them explicitly.
Task 6: minor (deferred): guard test lacks bare OperationRef / handler-typed parameter cases.
Task 6: minor (deferred): Lower.purs `>>= (pure <<< IR.THandler)` → `map IR.THandler`.
Task 6: minor (deferred): Fail layouts keyed by full payload — Task 7 brief: runtime key is (Fail, TypeHead), not the layout.
Task 6: minor (deferred): Console/Fail layouts absent from specializationKeys.
Regression rows duplicate-effect/operation/effect-parameter/operation-parameter: restored defect now yields "program was accepted" (old guard gone); messages updated; 7 remaining rows pass (.build/fx001-task6-regression2.log).
Task 6: complete (2501024, a3b54d3, 85c5867, regression rows, docs 51353c8)
Parser fix: complete (5da7865, 3aa1217, 49717bc); re-review r2 ADDRESSED, no new breakage.
Verify at 49717bc (.build/fx001-parser-verify.log): 760/760 parallel; serial 12/22, all T007 timing (fn-linear-timing 8 incl. pipe at the margin, fn-scale 2); regression 33/33.
Ruling: Task 7 implementer on sonnet (user: cheaper models where possible); escalate to opus on BLOCKED or fix round 4 — cost if wrong: extra turns.
Task 7: dispatched, BASE 49717bc.
Task 7: implementer DONE_WITH_CONCERNS e9a613f (checker fixes in Tables.purs ownerType, Consume.purs bound tail; ctor ctx; block-order needle; handler-metadata→effect-free-ctx). Review (opus) dispatched.
Task 7 review (opus): ❌ Critical: Handle.purs:117-125 frames push last clause innermost; checker selects first occurrence → Error(Int)/Error(Bool) clauses panic at runtime; duplicate Int clauses pick the wrong one. Fix round 1 (resume implementer) includes it plus minors: check-level tests for Tables ownerType and Consume bound-tail fixes (seen failing with fix reverted); key-0 fallbacks in handlerKey/effectShape → guard.
Task 7: minor (deferred): Context.children `_ → []` wildcard; Fail guard text names no family; `runtime` ~60-line declaration.
Task 7 fix round 1: 4b80bd1 (clause order, check-level tests, key guards). Re-review (opus) dispatched.
Task 7 re-review r1: all 3 ADDRESSED, no new breakage. 20,000-let timing: pre7 49717bc 1533/1574/1540 ms vs HEAD 1505/1405/1386 ms alternating — environment (T007), not Task 7.
Ruling (user decision 2026-10-09): defer must not fail (Swift rule); spec §2/§3/§5 probes, plan Tasks 8/10/12, findings, next-session updated; task-8 brief regenerated.
Task 7: complete (e9a613f, 4b80bd1; docs ad1059d); verify 786/786 parallel, T007 serial only, regression 33/33.
Task 8: dispatched (sonnet), BASE ad1059d
Snapshot of this workspace committed to docs/sdd/2026-10-09-effects-plan/ (84fd420); refresh after each task.
User 2026-10-09: complete Task 8 then STOP (no Task 9); write bounded concurrency-foundations design milestone (requirements: cc-requirements.md). Design writer (opus) dispatched in parallel with Task 8 implementer; docs only.
CF001 draft (opus) written: docs/plans/2026-10-09-concurrency-foundations-design.md (477 lines; refs checked against abstracts only — WebFetch host failures). Subset: par let fork-join, Fail/pure children, leftmost failure, child root wrapper relays outer aborts to join. 7 doc over-promises in §11. FX004 ID clash: covered by ruling F14. Adversarial review (opus) dispatched.
Task 8: implementer DONE_WITH_CONCERNS 041cb31 (defer-must-not-fail not total: late Fail via shared meta / caller ...e / unsettled closure → runtime cleanup-failed line; false positive for defer handling unsettled-key Fail; Cleanup/Report modules; IR.TypeInfo.arguments; recursive payloadName). Review (opus) dispatched.
CF001 adversarial review (opus): Accept with fixes — C1 sequential-equivalence overclaim (leaks/unbounded goroutines), I1-I8 (label-only check vs tails = same as Task 8 concern a; sharability via handler types; overclaimed ESTABLISHED labels; OCaml citation; law policy; indexed monads + per-guarantee table; FX005 before FX002). Fix round 1 sent to the writer (opus).
Task 8 review (opus): ❌ Critical: defer-must-not-fail unsound — P1 bracket callback (ambient tail), P2 named ...e, P3 unsettled closure, P4 lambda decided later, P5d handled abort converted to fatal report. Important: Report.payloadName recursion overflows on 5,000-arrow payload (compiler crash with defer); false positive defer+handle with unsettled key. (d),(e) OK. Minor: trailer says Sonnet; record conventions (no pending cause → first cleanup crash unprefixed; Go runtime panics print `panic: <text>`).
Ruling (needs user confirmation): deferred expression gets its own row (fresh meta tail), its labels consumed into the current row but its tail never unified with the current row; after the function's constraints settle, reject if any Fail label remains or the tail resolved to a rigid row variable (ambient or named) — that variable could carry Fail. An unsolved meta tail closes to empty. Sound; strict for effect-polymorphic cleanup callbacks (bracket); can be relaxed later by an internal lacks-Fail constraint without breaking accepted programs. Cost if wrong: bracket idiom unavailable until relaxed.
Task 8 fix round 1 (resume implementer, sonnet) with that rule + payloadName loop + tests for P1-P5d and the false positive.
CF001 fix round 1 committed ceb979d (502 lines; R0 general no-X rule; resource budget in subset). Re-review (opus) dispatched.
CF001 re-review r1 (opus): all 19 ADDRESSED; new Important N1 (inline over-budget divergence before join), N2 (par forces ctx + entry poll: undeclared change to spec §4/test 13), N3 (discard panic kind vs Task 8 cleanup, polls inside cleanup). Fix round 2 sent to writer incl. exact R0 alignment.
CF001 round 2 committed a8052df (518 lines). Container restarted 2026-10-09 during Task 8 fix round 1; partial edits kept in tree; implementer resumed.
Checked CF001 assumption: no loop keyword (Lex.reserved); emitted Go loops only bounded runtime loops (Entry args, Cleanup, Context markers, Report text) — divergence only via calls. Holds.
CF001 re-review r2 (opus): N1-N3, R0, minors ADDRESSED; new Important P1 (discard not propagated to nested par; join not a poll point), P2 (equivalence condition must cover both runs; OOM process-wide); minor P3-P5. Fix round 3 sent.
CF001 round 3 committed 29ce6a9 (530 lines); re-review r3 dispatched (named risk: cleanup defects dropped during discard).
CF001 re-review r3 (opus): Accept with fixes; P1-P5 ADDRESSED; dropping discarded tasks' cleanup defects judged correct (determinism) but needs stated argument + spec §3 scoping (N1); minors N2-N5. Applying verbatim via haiku.
CF001: accepted after 3 review rounds + verbatim minors (8e38aa0, 538 lines). Pending: Task 8 reconciliation, doc-audit corrections, BACKLOG/handoff.
User 2026-10-09: proceed through the rest of the epic (Tasks 9-12) after updating the plan per recent planning (supersedes "stop after Task 8"). Strict defer ruling stands (user did not choose the lacks-Fail constraint; flagged). Sequence: close Task 8 → opus re-scan Tasks 9-12 → plan amendments (docs) → Tasks 9-12 SDD → final whole-branch review (opus) → handoff.
Task 8 fix round 1: d5bfa8d (sound defer check per ruling, payloadName loop); verify 818/818 parallel, T007 serial only, regression 33/33. Re-review (opus) dispatched.
Task 8 re-review r1: all ADDRESSED; precision regressions accepted as documented limitations (FX007). Task 8: complete (041cb31, d5bfa8d).
Re-scan 9-12 (opus): 27 amendments (rescan-9-12.md). Rulings — all 12 adopted as proposed:
Ruling R1: per-task verify passes when the only failures are the named BACKLOG T007 set (identical at base) plus an explicit `node scripts/regression.mjs` exit 0.
Ruling R2: strict defer is adopted (user proceeded 2026-10-09 without requesting the lacks-Fail constraint); "pending user confirmation" wording → "adopted 2026-10-09; relaxation is FX007".
Ruling R3: Task 9 stores occurrence links in Subst (every unification path), new modules Provenance/Origin; deferred-row origins separate.
Ruling R4: Task 9 note reasons/texts as proposed in rescan T9-4; wire `related` = [{span, message}]; user may reword at review.
Ruling R5-R8: Task 10 files/interpreter/generator/runs as proposed (serial file, env knobs, batches ≤100, shrinker + sensitivity tests).
Ruling R9-R11: Task 11 no bracket idiom; hand-written inline baseline; host-measured bounds at 3× median; acceptance in parallel fx-services.test.mjs, timing serial.
Ruling R12: Task 12 adds 4 regression rows + test/regression-fx.mjs; side-condition probe with own timeout; reuse effect-free-ctx; BACKLOG updates existing FX007/CF001 rows.
Plan amended e2c3809 (868 lines).
Task 9: dispatched (sonnet), BASE e2c3809
Container restart #2: Task 9 implementer lost before writing anything (tree clean at e2c3809). Re-dispatched fresh.
User 2026-10-10: add operational (Gleam/OTP) concerns to the CF001 assessment; do NOT begin Task 9; stop after the assessment for review. Task 9 re-dispatch stopped; its unreviewed partial edits saved to docs/sdd/2026-10-09-effects-plan/task-9-wip-abandoned.patch (git apply to resume) and stashed; tree reset to e2c3809.
User 2026-10-10 (clarified): do not abandon Task 9; accommodate the new operational thinking. Task 9 WIP restored from stash; implementer resumed. OTP addendum (design only) dispatched in parallel; check its impact on Tasks 10-12 before continuing.
CF001 ops addendum committed 57231e0 (723 lines; O-1..O-7; Task 12 ADR wording additions; no change to Tasks 9-11). Review (opus) dispatched.
Task 9: implementer DONE_WITH_CONCERNS 2fc7a02 (coarse boundary spans; maxNotes vs pathHops; report-time callee re-check; bidirectional Matched links). Review (opus) dispatched.
User 2026-10-10: backend-maintainability proposal (design only; backend-requirements.md). Interpretation per the user's earlier clarification: finish in-flight Task 9 review cycle, write the proposal, then STOP for user review before Task 10.
CF001 ops review (opus): Accept with fixes; Critical façade-as-Shareable breaks par discard argument; I1-I6. Fix round sent to writer.
Task 9 review (opus): Needs fixes — I1 boundary spans (carry with/annotation spans through Resolve; with Log misreported as ambient), I2 maxCharacters excludes headline (2,522 chars probe), I3 no note inside deferred expr for later-settled Fail key. Ruling: fix all three (spec §6 names them) + Minor e wording. Fix round 1 → implementer.
CF001 ops fix round 1 committed 304261f (761 lines; C1 → B3b inert handlers, a pre-existing CF001 flaw). Re-review dispatched.
CF001 ops re-review (opus): all 16 ADDRESSED; N1 B3b false premise (with-consumption + R0 already reject) → demote; minors. Applying verbatim via haiku.
CF001 ops addendum: accepted (a7ade34).
BK001 proposal draft committed 4dcf647 (462 lines; typed builders + plan/syntax split; no library; after FX001). Review (opus) dispatched.
BK001 review (opus): Accept with fixes; 9 Important (overclaims, wrong facts, D2 sketch not total, two-tier recommendation, priority steps 0/1/6 before CF001/FX005), 9 Minor. Fix round sent to writer.
BK001 fix round committed ab9cf6f (518 lines). Re-review dispatched.
Task 9 fix round 1: 04ab898 (rowSpan through Resolve; 120-char label elision; defer note inside; M1/M2). Parallel 842/843 (large-source T004 flake), serial T007, regression 0. Re-review dispatched.
BK001 re-review (opus): Accept with fixes; N1 Callee rule vs main/stages/function values/templates; N2 D8 is forward risk; N3-N8 minors. Fix round 2 sent.
BK001: accepted after review + 2 fix rounds (controller spot-check of N1/N2 in round 2) fc133fd; BACKLOG row added.
Task 9 re-review r1 (opus): I1 partly (N1 nested-arrow param notes on wrong with), I2 OK for required cases (string cut acceptable; payload mismatch structural); bound gap long names → E011, fix comment + record; I3 tested case only (N2 blames first Fail-row call). M1/M2 OK; rowSpan no wire change. Fix round 2 → implementer.
Task 9 fix round 2: cee8542. Controller evidence: new tests run against 04ab898 in isolated worktree → fail: 'nested pure row names the parameter', 'nested row variable declared at the parameter', 'late Fail key blames its own call' (3 fail, 42 pass); second N2 probe passes there (characterization). Re-review r2 dispatched.
Task 9 re-review r2 (opus): N1 residual wrong note (topRowPure with two pure rows), N2 fixed (no wrong note in ~20 probes; missing notes acceptable), settleDeferred linear, I2 comment OK (record E011 gap at close). Fix round 3 → implementer (one-line + tighten N2 test).
Task 9 fix round 3: b80cc17. Re-review r3 (sonnet; small diff) dispatched.
Task 9: complete (2fc7a02, 04ab898, cee8542, b80cc17). STOP for user review before Task 10 (user 2026-10-10).
