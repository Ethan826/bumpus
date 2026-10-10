# Re-review 2: parser fix round 2 (51353c8..49717bc)

### Finding Verdicts

**Important: `sole` ignored `found.row` when the lone argument's chain also carried a row: ADDRESSED.**

- src/Format/Parse/HandlerType.purs:66-71: with one argument, `sole` now runs `maybe' (lifted first) (Left <<< unexpectedRow) found.row`. If there is no trailing row, the argument's row is lifted (line 71, as before). If there is one, it is rejected with E_SYNTAX "Unexpected effect row". The span is that trailing row: `found.row` is read by `optionalOn "with" (rowRef parser)` at line 51, after the argument chain has taken the first `with`. Neither row can be dropped silently now. `apply` (line 61) runs `liftedRow` first and short-circuits on `Left`, so `withRow` never sees a half-accepted row.
- The other paths are unchanged and still correct. With several arguments, a row on any argument is rejected (line 70). With no argument rows, `kept` passes `found.row` through (line 65).
- test/fx-handler-type.test.mjs:114-122: covers both orders (`with Log with pure` and `with pure with Log`) and checks code, message and span (`with <second>`). This matches the brief: written rows are never silently dropped.
- Confirmed at HEAD: output/Format.Parse.HandlerType/index.js (mtime 21:20:30, commit 21:20:48) contains the new `lifted`/`unexpectedRow` branch. `node --test test/fx-handler-type.test.mjs` gives 20 pass, 0 fail.

### New Breakage in the Fix Diff

None. The change is confined to the single-argument case where both rows are present, which was the buggy acceptance. The single row form `Handler(Clock with Log)` still lifts the row (the existing shape tests pass). The rest of the diff is tests. There is no `case` on Maybe and no `>>=`, so it matches the structural-gate idioms.

### Out-of-Scope Observations

- The failing "20,000 let items compile in linear time" test (test/fx-block.serial.test.mjs:15-23) is plausibly load, not a regression:
  - The bound is 3 × 500 ms = 1,500 ms, and the passing solo run took 1.4 s, which is already about 93% of the bound in this environment.
  - The file's header comment (lines 7-9) says it is meant to run serially because parallel load inflates it. scripts/verify.mjs:31-38 runs `*.serial.test.mjs` files separately for that reason. The implementer's `test/fx-*.test.mjs` glob pulled the serial file into a parallel run, against that design.
  - The fix only touches the `Handler(` argument path, which a let-block program does not reach.
- Separate concern: a 1.4 s solo time against 1.5 s leaves little headroom on this machine, so the test may flake even in verify's serial phase. That is a calibration issue (measuredMs = 500 was taken on the author's laptop) and has nothing to do with this fix.
