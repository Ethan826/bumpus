# Review: CF001 operational addendum (§8A), 2026-10-10

Scope: docs/plans/2026-10-09-concurrency-foundations-design.md §8A (lines 351-508)
and the edits at 3-6, 22-23, 566-570, 588-589, 593, 630-635, 701-702, 722-723.
Checked against cc-requirements-ops.md, D §3 and decision 9, src/Format/Go/Cleanup.purs,
Report.purs, plan Tasks 10 and 12, and the rest of CF001 (§2, §5, §6, §7).
Sources re-fetched by curl on 2026-10-10: gleam-otp v1.3.0 `actor`, `static_supervisor`,
`supervision`; pkg.go.dev/runtime.

## Coverage

| Requirement bullet | | Where | Note |
|---|---|---|---|
| Structured concurrency vs supervision (dependencies, limits, resources across restarts) | ✅ | 358-392, O-4 | T/R/P given at 387-389. Gaps on restart under diverging or defecting cleanup (I3) |
| Defect boundaries (cleanup, task end, supervisor notice, escalation; Task 8 unchanged; compatibility) | ✅ | 394-415, O-1, O-5, 630-635 | Programs without tasks are unchanged. Gaps: I2, I4, I5 |
| State ownership: task-local, actors, shared capabilities; ownership, regions, laws | ✅ | 417-431, O-3 | Contradicts §6 (C1) |
| Overload and communication; typed messages do not prove deadlock freedom, determinism or bounded resources | ✅ | 433-450 | Mostly precise (M3, M4) |
| Observability: minimum runtime support | ✅ | 452-469, O-6 | Has no T/R/P columns (M7). Reservation list inconsistent (M5) |
| Host boundaries: exports, callbacks, imports, lifetimes, cancellation, typed failures, defects crossing host frames | ⚠ | 471-483, O-7 | Two gaps: a Waxwing defect unwinding through Go frames in a scoped callback, and non-Go host frames (M6). An unsupervised escaping-callback defect (I5) |
| Practical delivery: tooling, no milestone expansion | ✅ | 485-494 | |
| Gleam/OTP as a comparison, with bounded sources | ✅ | 354-356, 367-373, 378, 442-444, 701 | Accurate (see below) |
| T/R/P for each recommended abstraction | ⚠ | | Missing for 8A.2 and 8A.5 (M7) |
| Which contracts to decide now and which can wait | ✅ | 496-508, 588, 593 | |

Verified accurate:
- Gleam strategies (RestForOne: "the terminated child process and all child processes after it are restarted").
- Gleam restart types.
- Restart tolerance ("more than MaxR restarts ... within MaxT seconds, the supervisor terminates all child processes and then itself"; defaults 2 and 5).
- `Worker(shutdown_ms)`.
- `named` takeover quote.
- `call` timeout crashes the caller ("rather than leaving the processes in an invalid state").
- The Gleam pages state no mailbox bound.
- Go runtime: an unrecovered panic or fatal error "exits with exit code 2". Caveat in I4.
- pprof `debug=2` and label inheritance, and the `//line` purpose: these match the Go docs as I know them. I did not re-fetch them.

No ESTABLISHED labels are added in §8A. Nothing speculative is presented as recommended, except the field reservation in M5.

## Critical

**C1. Lines 425, 428-431, 501 (O-3) and 566-570: a Shareable façade breaks CF001's equivalence, and the addendum says no conflict.**
- Problem:
  - A façade `Handler(Counter)` whose clauses only send and await is Shareable under B3 (line 425: "façade Shareable").
  - By B2, a clause's own effects never appear in the child's row. So `par let a = with c { tick() }, b = with c { tick() };` (line 430) has Fail-only child rows and Shareable captures. R0 and B3 both accept it.
  - Its effect is a mutation at the owner. A child discarded after sending `tick` has done something observable, but sequentially it never ran.
  - §6's justification ("discarding equals never having run ... holds for Fail-only rows (R0) with Shareable captures (B3)") is false once façades exist.
  - Line 566 nevertheless states "§8A found no conflict", and O-3 is a decide-now contract.
- Why it matters: send and await are runtime primitives that do not appear in any row. Row-based R0 cannot see them, so the CF001 equivalence would silently stop holding in FX002.
- Fix:
  - Add to O-3 and to the §9 impact note: "A handler whose clauses communicate (façade) or touch shared state is Shareable but not *inert*. A `par` child (R0) may capture only inert handlers: those whose clause rows, transitively, are Fail-only and which use no runtime communication primitive. Alternatively, a façade's clause row carries a non-Fail `Send` label, and R0 for `par` also inspects the clause rows of captured handlers."
  - State that FX002 must adopt one of these before façades exist.
  - Change "no conflict" to "no conflict for FX001/CF001 programs; FX002 façades need the inertness rule (O-3)".

## Important

**I1. Line 406 and O-1 (499): "uncatchable" is redefined, but what the supervisor exposes is left open.**
- Problem: "no Waxwing expression observes a defect; only task roots do" holds only if a supervisor is runtime policy with no user hook that receives causes. If an API lets user code await a Temporary child's outcome (or log it), spawning a task becomes `try` for defects.
- Why: D decision 9 does allow catching at supervision boundaries (it leaves this to the follow-up), but O-1 is to be "settled now" and is ambiguous on exactly that point.
- Fix: add to O-1 either "supervisors act on defects only by built-in policy (restart, escalate, event line), and no Waxwing code receives a cause list", or "a task boundary is the only defect catch point (D9's supervision boundary); its observer receives an opaque cause value". Name which one is recommended.

**I2. Line 408 and O-1/O-4: no destination for causes from cancelled services.**
- Problem: the causes row defers cancelled siblings to "C2". C2 reports a cleanup defect "only if that task is selected", and selection is defined only for `par` (§6). Undefined cases:
  - OneForAll or RestForOne terminating siblings whose cleanup defects;
  - supervisor shutdown in reverse start order whose cleanups defect.
  For each, it is not said whether such causes are dropped (the §6 `X` rule), count toward intensity, or become the escalated cause.
- Why: the requirement asks for cleanup, termination, notification and escalation together. "Compatible" is asserted without a rule.
- Fix: one sentence. Recommend: "a task cancelled by its supervisor records `X` (as discard). Its cleanup causes go only to the supervisor's event line, never to intensity or the report. Only the triggering child's causes escalate."

**I3. Line 383 and O-4 (502): restart under a diverging or defecting cleanup, and intensity accounting.**
- Problem: "defers run exactly once first" says nothing about cleanup that diverges (line 372 covers only shutdown) or that defects during a restart. If the supervisor abandons the cleanup after `shutdown_ms` and starts a fresh activation, the old goroutine keeps running beside the new one. Exactly-once-to-completion (§6, C3) no longer holds, and resources the old activation was releasing may be reacquired concurrently.
- Intensity accounting is also unstated:
  - whether a cleanup defect adds a restart or folds into the one failure;
  - whether an initializer that fails immediately counts.
- Fix: add to O-4: "a restart starts only after the old activation's cleanup completes. If it exceeds the shutdown deadline, the child is abandoned (dump-visible), never restarted, and the supervisor escalates. A cleanup defect is part of the one failure's cause list and counts once." Leave the counting window to "later".

**I4. Lines 410, 503 (O-5) and 633: the "exit 1 Waxwing vs exit 2 Go fatal" split is not a fact about current programs.**
- Problem 1, Cleanup.purs `guardedMain`: `waxwingReport` is installed only when `usesDefects` (the program contains `defer` or `crash`). In every other program, the recoverable guard panics exit 2 with a Go trace, not 1 with a report:
  - `no handler for L` (Context.purs:139);
  - `waxwing: unmatched value` (Match.purs:84);
  - `waxwing: malformed value` (Data.purs:92).
- Problem 2: panics on goroutines that Waxwing did not root (library goroutines, line 475) also exit 2.
- Problem 3: Go's "exit code 2" is the GOTRACEBACK default only. With `GOTRACEBACK=crash`, the runtime "crashes in an operating system-specific manner instead of exiting" (SIGABRT on Unix).
- Why: line 633 recommends putting "Go fatal errors exit 2" into ADR 010, which would read as a Waxwing guarantee.
- Fix:
  - O-5 and line 633 should read: "exit 1 after a Waxwing report; any failure Go reports itself (fatal errors; unrecovered panics, including guard panics in programs without the defect runtime and panics on unrooted goroutines) follows Go's GOTRACEBACK behaviour, by default exit 2. This is Go's, not a Waxwing guarantee."
  - Row 410's Task 8 column: add "when `usesDefects`".

**I5. Line 477 (escaping callback): "defects to its owning supervisor, else the report".**
- Problem: the report is `main`'s deferred `waxwingReport`, which cannot recover a panic on another goroutine. There are two outcomes, and both need a rule:
  - forward to `main`'s root: this requires asynchronously cancelling `main`'s tree (C1-C4) so that `main`'s cleanup runs before it reports;
  - report and exit from the callback's goroutine: this skips `main`'s cleanup, contradicting D §3 "cleanup runs on defects".
- Why: this is the one place where §8A would change Task 8's observable behaviour (the report originating outside `main`) without saying so.
- Fix: state "an unsupervised escaping-callback or service defect cancels `main`'s scope; `main`'s root reports after its cleanup (exit 1)". Add this to O-7 as a compatibility point.

**I6. Lines 408-409, plan Task 12, and the defect-report format (question 6): the "cleanup failed: " prefix is positional.**
- Problem: Cleanup.purs prefixes every cause at index > 0. The addendum adds non-cleanup causes: a restart-limit cause (409) and FX002 secondary lines. Whether the escalated restart-limit cause goes first or last, it would get the "cleanup failed: " prefix or be misread as one.
- Why: line 409 says "compatible if ADR 010 calls the kinds an open set", but the prefix rule also has to be open. A cheap wording fix now avoids a format break later.
- Fix: in the ADR 010 recommendation at 631-633, add "`cleanup failed: ` marks causes raised by cleanup (today every non-first cause); future non-cleanup causes get their own prefix". No code change and no Task 10 interpreter change: in FX001 the two readings coincide. The impact claim (Task 12 wording only) otherwise holds.

## Minor

- **M1. Line 364: the reason for O-2 is wrong as stated.**
  - Problem: "no blocked parent keeps a target live". Yet line 367 makes a supervisor a scope inside its parent, so a `handle` enclosing the supervisor *is* live.
  - Real reasons: the parent body is not at a join point when a service fails, so there is no defined delivery point; and a restartable child must not end the enclosing `handle`.
  - Fix: reword. O-2 itself is sound, consistent with R0, and compatible with typed replies.
- **M2. Line 377: "RestForOne restarts exactly the holders of invalidated façades" is overstated.**
  - Problem: RestForOne restarts every later child, which is a superset of the holders.
  - Fix: "at least the holders".
- **M3. Lines 425 and 448-449: two determinism claims are too strong.**
  - "commutative messages give an order-independent final state" needs each message applied exactly once. Line 440's removal of an unstarted request on timeout makes the applied set depend on timing. It also needs that no reply exposes intermediate state.
  - "one sender per mailbox" needs the sender itself to be deterministic and no deadlines.
  - "semilattice state with threshold reads" in a user actor conflicts with §4.7 (blocking lattice reads are for trusted built-ins only).
  - Fix: add these qualifiers.
- **M4. Lines 445-447: deadlock causes are incomplete.**
  - Bounded mailboxes with blocking sends add deadlocks of their own: two services each blocked sending into the other's full mailbox. The one-shot reply slot covers replies only.
  - C5 (waiting in cleanup) is a further deadlock source.
  - Fix: name both, and cross-reference the self-call and cycle cases from O-3 (501).
- **M5. Lines 456-460 vs 504 (O-6) vs 566-570: the field reservation is inconsistent and speculative.**
  - Problem: §9 adds id, parent and name to CF001. O-6 and the 8A.5 column also reserve blocked-on and cancellation-reason fields. None of them has a CF001 consumer.
  - Fix: reserve them in the *contract* (O-6) only, not as CF001 fields, or make all three places agree.
- **M6. Line 476: scoped callbacks cover aborts only, not defects.**
  - Problem: a scoped callback says nothing about a *defect* unwinding through foreign Go frames, which runs the library's `defer`s and leaves its locks or state mid-operation.
  - Also missing: non-Go host frames. Go panics must not unwind through C frames under cgo.
  - Fix: "adapters recover at the callback boundary and re-raise after the foreign call returns; never unwind through C frames".
- **M7. 8A.2 and 8A.5 lack the T/R/P split that the requirement asks for "for each recommended abstraction".**
  - Fix: add a T/R/P line under each table. For 8A.5, T is nothing beyond C1's explicit task identity; R is all of it; P is the dump trigger and labels.
- **M8. Line 406: escaping-callback roots are missing from the list of roots that act on defects.**
  - Problem: the list names `par` joins, supervisors and export roots; line 477 also has escaping-callback roots acting.
  - Fix: add them.
- **M9. Line 439: blocking waits are not C1 cancellation points.**
  - Problem: "expiry cancels the scope (C1-C4)". C1's delivery points do not include blocking waits (send, receive, reply await); only §6 joins are covered.
  - Fix: add "every blocking wait is a cancellation point" to O-7 or to the C1 handoff.

## Verdict

**Accept with fixes.** O-1 to O-7 have the right shape. Gleam/OTP is represented accurately and used only as a comparison. Task 8 behaviour for programs without tasks is unchanged. The fixes:
- C1 (the façade inertness rule; correct the "no conflict" claim);
- I4 (exit-code wording headed for ADR 010) and I6 (the prefix wording) before Task 12;
- I1-I3 and I5 as one-sentence contract amendments to O-1, O-4 and O-7.

No change to Task 10 or to the report code is needed now.
