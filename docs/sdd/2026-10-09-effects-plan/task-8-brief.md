### Task 8: `defer`, `crash`, cleanup policy and the defect report

**Files:**
- Modify: Block parser/checker/lowering (`Defer` item), `src/Domain/IR/
  Internal.purs` (`Defer`, `Crash`), `src/Format/Go/Context.purs`
  (`waxwingCleanup`, `waxwingDefect`, main's recovery wrapper); `defer` and
  `crash` go through every phase in this task
- Create: `src/Features/Check/Defer.purs`, `test/fx-cleanup.test.mjs`

**Interfaces:**
- §3 exactly: registration context; whole expression evaluated at exit;
  LIFO; four block exits; cleanup-failure policy (revised by the user
  2026-10-09: `defer` must not fail; only defects fail cleanup);
  `crash(value: a): b` printable argument, no effect, uncatchable.
- §2 `defer` rule: `e : Unit` against the current row; any `Fail` label it
  performs and does not handle inside `e` (deferred keys included) is
  E_EFFECT `defer must not fail, but it performs <L>` at the `defer`.
- Report lines and exit status 1 per Global Constraints; `<not
  printable>` decided statically from the payload type.

- [ ] **Step 1: Write failing tests** (exact stdout, stderr, exit status):
  LIFO order; unreached `defer` never runs; two crashing defers on normal
  exit; abort with crashing cleanup (`fail(DbError): …` then `cleanup
  failed: crash: …`); multiple recoverable defects in order; cleanup
  handling its own failure while an outer abort is pending completes
  normally and the abort then reaches its `handle`; cleanup performing
  an operation under nested handlers while an abort unwinds uses the
  registration context; `crash` not caught by `handle`; non-printable
  payload line; a block without `defer` emits no Go `defer`; rejections
  (exact code, text, span): `defer` performing an unhandled `Fail`
  directly, through a called function, and through a deferred Fail key;
  accepted: `defer` handling its own `Fail`, and `defer` performing a
  non-Fail effect from the current row.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: defer, crash and cleanup (FX001)`.

