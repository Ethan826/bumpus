### Task 10: Reference interpreter and differential execution

**Files:**
- Create: `test/fx-oracle-parse.mjs` (independent parser for the effect
  forms; extends test/poly-parse.mjs by import, which stays unedited at
  226 lines; parses zero-argument calls `f()`, FN006 (1)),
  `test/fx-oracle.mjs` (interpreter; no compiler code imported; split
  further to stay within 250 lines), `test/fx-programs.mjs` (generator,
  census), `test/fx-shrink.mjs`, `test/fx-oracle.test.mjs` (hand-trace
  validation, shrinker test, sensitivity check; parallel phase),
  `test/fx-differential.serial.test.mjs` (generated comparisons, serial
  phase, ruling F11), `test/fx-cleanup-programs.mjs` (Task 8's run cases
  moved unchanged out of test/fx-cleanup.test.mjs)
- Modify: `test/fx-cleanup.test.mjs` and any other probe file whose run
  cases are inline (import them instead), `docs/engineering.md` (the
  corpus knobs)

- [ ] **Step 1: Write** the interpreter. Validate it first against
  hand-derived traces: every executable probe of Tasks 2, 4, 7 and 8
  (fx-block-programs `runs`, the Console probes, fx-run-programs `cases` with
  empty stderr and status 0, fx-cleanup-programs with stdout, stderr and
  status), imported, never copied. Task 5 tests are check-only and Task 6 has
  no executable probes (F12). Cases whose Go is transformed after emission
  (fx-cleanup `injected`: missing-handler guard, newline escaping) are outside
  the interpreter's language and are listed by name as excluded in the test. A
  disagreement there is an interpreter or probe defect, investigated before
  Step 3.

  The interpreter models the shipped semantics exactly: handler lookup by
  runtime key, user effects by effect identity regardless of type arguments
  (innermost State wins for State(Int) and State(Bool)), and `Fail` by the
  payload's declared head (Error(Int) and Error(Bool) share a key). The
  clauses of one `handle` are frames with the first clause innermost. A clause
  runs in its `with`'s outer context. Aborts target their frame. `defer`
  registers when reached and runs LIFO, once per exiting activation, in the
  registration context. A pending abort reaches its `handle` only if every
  cleanup on the way completes normally. If a cleanup crashes, the pending
  abort heads the report as `fail(T): V` and its `handle` never runs. With no
  pending cause, the first cleanup crash is the unprefixed first line. Later
  causes follow with `cleanup failed: `, in execution order. Payloads print by
  ADR 005, or `<not printable>` when T contains a function or handler, with
  `\n` escaped; output goes to stderr and the exit status is 1. A deferred
  expression that ends in a typed abort is an interpreter error, "typed abort
  escaped cleanup", reported as a difference: it witnesses a hole in the
  strict `defer` rule. Go runtime panics and the missing-handler guard cannot
  be produced by generated programs and are not modeled.
- [ ] **Step 2: Write** a generator of well-typed programs over two user
  effects with Console traces, and a per-program feature census. Required
  coverage per run, failing the run when unmet: at least 50 programs each with
  nested same-key handlers (including intercept-and-forward), targeted aborts
  crossing an unrelated `handle`, interleaved stage ordering with
  over-application, and escaped callbacks invoked under a different handler;
  at least 25 each for every cleanup outcome (normal exit, abort, defect,
  crashing cleanup on normal exit, crashing cleanup while an abort is pending
  (the abort heads the report), several crashing cleanups (order), cleanup
  handling its own failure while an abort is pending (the abort then reaches
  its `handle`), cleanup performing an operation under nested handlers while
  an abort unwinds (registration context), unreached `defer`). The census is
  printed with the run. Generated `defer` items obey the strict rule (spec
  §2). They perform only non-`Fail` labels from operations or named functions
  with written rows, or they handle their `Fail` inside (`defer handle … {
  fail(error: E) => … }`). They never call a callback parameter, or a local
  lambda also called outside the `defer` in a non-`main` function (FX007).
  Every generated program must compile, and a rejection fails the run with its
  seed (a generator defect). In addition, 25 generated rejection variants (a
  `defer` failing directly, through a called function, through a callback
  parameter with an ambient row, and through one with a named row) must give
  E_EFFECT with the exact Task 8 texts and the `defer` span. Payload types are
  monomorphic, or derivable from constructors and literals, so the interpreter
  can name T as diagnostics print it.
- [ ] **Step 3: Run** in test/fx-differential.serial.test.mjs (F11), generated
  comparisons of Go stdout, stderr and exit status against the interpreter:
  500 programs by default from a fixed seed, with `WAXWING_FX_SEED` and
  `WAXWING_FX_PROGRAMS` for larger runs outside verify (documented in
  docs/engineering.md), built in go-batches of at most 100 programs each (a
  batch-level Go failure names its chunk; go-batch's build timeout is 300 s),
  with the coverage above. Expected: 0 differences. Every program's seed is
  recorded; a differing program's seed and source are written to
  .build/fx001-differential/, and a shrinker (drop block items, handlers,
  clauses and defers; replace subexpressions by literals of their type; keep
  only while still well-typed and still differing) writes the minimized source
  beside it. test/fx-oracle.test.mjs proves the shrinker on a synthetic
  "differs" predicate: it removes items and keeps the program well-typed. It
  also runs a sensitivity check: 50 generated programs against an interpreter
  flag that runs clauses in the inner context must give at least one
  difference.
- [ ] **Step 4: Run** `rm -rf output && npm run verify` (G1) and add the
  progress entry (census, seed, counts, run time).
- [ ] **Step 5: Commit** `test: FX001 reference interpreter and differential
  corpus`.

