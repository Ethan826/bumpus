# Re-review: FX001 Task 8 fix round 1 (041cb31..d5bfa8d)

Method: I read the fix diff once. I ran
`GOTOOLCHAIN=go1.26.4 node --test test/fx-cleanup.test.mjs` (32/32 pass). I
reran every program in `.build/review8/progs*.json` through `output/` (built at
d5bfa8d) with a copy of the probe that writes into the scratchpad, and added
new-breakage probes. Nothing in the working tree, the index or HEAD was
changed.

### Finding Verdicts

- **Critical 1: ADDRESSED.** The fix matches the controller ruling.
  - src/Features/Check/Defer.purs:43-53. `e` is inferred against its own
    `openRow (Hole state.next)`. Its resolved labels are consumed with a
    fresh tail, `Row labels (Just (Hole typed.next))` at :46, so the tail is
    never unified with the enclosing row. `{span, row, current}` is recorded.
  - src/Features/Check.purs:99-101. The order is
    `settleKeys` → `settleDeferred` → `settleKeys`.
  - Defer.purs:65-92. `judge` rejects any Fail label with `DeferMayFail` and
    a `Rigid` tail with `DeferMayPerform`. It prints `...` for the ambient
    row and `...e` for a named one, through `env.variables`. A `Hole` tail is
    accepted. Labels that arrive late, minus Fail, are consumed into the
    recorded `current`.
  - Texts (src/Format/Diagnostic.purs) are exactly
    `defer must not fail, but it performs <L>` and
    `defer must not fail, but it may perform any effect of <r>`, both
    E_EFFECT.
  - Probes, each with the span of the defer item:
    - P1: rejected with `...` at `defer release(())`.
    - P2: rejected with `...e`.
    - P3: rejected with `performs Fail(E)` at `defer f(y)`.
    - P4: rejected with `performs Fail(E)` at `defer h(())`.
    - P5, P5c and P5d: rejected with `...e` or `...`.
  - Tests at test/fx-cleanup.test.mjs:155-189 pin these cases.
  - Minor: an unsolved meta tail is accepted but never bound to empty
    (Defer.purs:91, `Hole _ → Right unit`). This is equivalent in practice,
    because only the second `settleKeys` runs afterwards and late Fail
    labels are filtered out.
- **Important 2: ADDRESSED.** src/Format/Go/Report.purs:59,68 walks the arrow
  spine with `IR.spine`, which is iterative (`tailRec` and `mapAccumL`), then
  uses `Array.foldr FunctionName`. Recursion stays only on parameters and
  type arguments, which the nesting limit bounds. The `spine5000` probe now
  compiles and runs (`crash: 0` / `cleanup failed: crash: 1`). The test is
  at test/fx-cleanup.test.mjs:199-205.
- **Important 3: ADDRESSED.** The postponed-pair scan is gone. P8/P6
  (`defer handle fail(p) {…}` with a key settled later) now compile and run
  (status 0). The test is at test/fx-cleanup.test.mjs:191-197.

### New Breakage

Legitimate defers that are accepted:

- N1: `defer log(1)` in `fn work(): Unit with Log`.
- N2: `defer print(x)` in main.
- N3: `defer helper()` where `fn helper(): Unit with Log`. The helper's
  ambient row is instantiated fresh at the call and is not rigid. N3b and
  N3c are the same pattern and are also accepted.
- N9: a polymorphic helper.
- N10: `apply(fn(_) => print(3))`.
- N8: a Console label arriving late.
- N5: a defer inside a lambda body.
- N4, N4b and N4c in main: a lambda called both normally and in a defer.
- N12: a lambda called only in the defer of a non-main function.

**Precision regression, a consequence of the ruling rather than an
implementation bug:** in a function that has an ambient row (any non-main
function), a local lambda that is also called outside the `defer` is
rejected.

- N11: `fn work(): Unit = { let g = fn(_) => (); g(()); defer g(()); () }`
- N6/N13: the same with `g = fn(_) => log(4)` in `fn work(): Unit with Log`,
  with the other call before or after the `defer`.

All three give `defer must not fail, but it may perform any effect of ...`.
The cause is that the plain call `g(())` consumes g's row into the current
row (src/Features/Check/Consume.purs `consume`, the `opened` branch, which
unifies the tails). g's tail then resolves to the rigid ambient row. A pure
or Log-only closure is therefore indistinguishable from an
ambient-polymorphic one. Main is unaffected because its row is closed.

The same rule also rejects P7: `defer handle release(()) { fail(e: E) => () }`
where `release: Unit -> Unit with Fail(E)` is a parameter. That is the strict
behaviour the ruling accepts. Spec §2's example uses `release(r)` without
saying whether it is a parameter or a global, so §2 should state that a
deferred callback parameter must be `with pure`.

The controller should decide whether N11 is acceptable and, if so, record
it in findings or BACKLOG next to the rigid-tail rule.

Linearity is preserved. `settleDeferred` does one `resolvedRow` and one
`consumeAt` per deferral, and both are bounded by the row size. Body
traversal adds only one extra `settleKeys` pass per function, not one per
defer. Timing `main` with N defers gives N=1000/2000/4000/8000 at
566/790/930/1937 ms, which is about linear.

### Out-of-Scope Observations

- The defer row's unsolved tail is not explicitly closed. If a later pass
  ever unifies rows after `settleDeferred`, it could bind that tail
  silently. Binding it to empty in `judge` would make this robust.
- `settleDeferred` judges every deferral before the late labels are
  consumed. Late labels are all non-Fail, so this order is sound. Swapping
  it later would be unsafe.
- The minor items from the previous review (docs conventions, the
  Go-literal comment) are not in this diff, as expected, since docs are the
  controller's.
