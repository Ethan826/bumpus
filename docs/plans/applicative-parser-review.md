# G001 final whole-branch review

Range 89fd96c..5268342 on branch g001, reviewed 2026-10-07 against
docs/plans/2026-10-07-applicative-parser-design.md and ADR 006. Findings
fixed in one wave, commit `fix: address G001 final review`. The
controller runs one scoped re-review of that commit.

## Verdict

With fixes: two Important findings (coverage and inhabitation still
overflowed on wide or long inputs that the docs called fixed), five Minor
findings selected for the fix wave, and the per-task deferred minors
triaged below.

## Findings and resolution

| Finding | Resolution |
|---|---|
| I1: a wide constructor pattern crashed coverage with a raw RangeError (`type T = C(Int × N); match t { C(b0, …) => b0 }`: 1,500 fields compiled, 1,600 and up overflowed). Features.Check.Usefulness recursed once per column in `usefulRows → column → usefulColumn → specialized` and in `missing`/`missingColumn`. BACKLOG E002, ADR 006 and progress.md claimed breadth was fixed; the 1,536-field test covered only the declaration. | Code. Usefulness (U(P, q)) and the new Features.Check.Missing (algorithm I) are `tailRecM` loops, one step per column. Untried heads of a complete column (usefulness) and the witness continuations `Alternatives`, `Rebuild` and `Prepend` (algorithm I) live on an explicit Features.Check.Search `Stack`, so the order of exploration, the first useful head, the canonical witness and every internal error are those of the recursive version. Shared matrix operations moved unchanged to Features.Check.Matrix. New test/coverage-scale.test.mjs, each bounded at 5 s: an exhaustive 5,000-field binder pattern, a 5,000-field non-exhaustive Bool match whose witness `C(false, _, …, _, false)` must match exactly, and a 5,000-field redundant arm at its exact span. RED on the pre-fix compiler: all three RangeError (.build/g001-final-fix-red.log). GREEN 0.27-0.36 s, 0.08 s, 0.05 s. The 300-case oracle, generated type systems, adt-coverage, diagnostics and the `exhaustive` regression row (needle once, mutant fails) pass. The algorithm is not exponential at 5,000 columns; it is quadratic in fields (BACKLOG E002 (5)): 5,000 / 10,000 / 20,000 binder fields compile in 0.27 / 0.92 / 3.55 s, of which about 3.1 s at 20,000 is Features.Resolve.Pattern `uniqueBinders` (profiled), not coverage; 20,000 Bool wildcard columns take 0.39 s. Docs corrected: BACKLOG E002 current state and the Task 2 history line, ADR 006 Context, architecture.md, findings.md. |
| I2: inhabitedness overflowed and was quadratic on type-dependency chains (`type T0 = A0(T1); …`: 2,000 types 1.26 s, 3,000 RangeError). The fixed point recomputed every constructor per pass, one pass per chain link, recursing once per pass. | Code. New Features.Check.Inhabited: a worklist over reverse indices (users of each type, types listing each constructor), built once by grouping sorted edges, in a `tailRecM` loop of rounds that revisit only the users of newly inhabited types. The old first pass's lookups run first, so a bad id fails with the same E_INTERNAL. The generated-type-system inhabitedness oracle passes. Test: a 10,000-type chain within 5 s, RED RangeError after 9.9 s, GREEN 0.64-0.69 s. While green, the existing 20,000 one-constructor-type test overflowed inside Array.modifyAtIndices (one ST bind per index; overflows between 6,000 and 8,000 indices), so flags are set 1,024 at a time; that test passes again (0.33 s; 100,000 types 1.42 s). Not linear: one round per link, each copying the flag arrays, O(edges·log edges + rounds·(types + constructors)). 10,000 / 20,000 / 40,000 chained types take 0.69 / 2.04 / 7.8 s; recorded in BACKLOG E002 (4) with why (no in-place counters in the pure allowlist). |
| M1: the Bind gate comment said "every Prelude route" but missed ap, ifM, whenM, unlessM, liftM1 (Prelude) and bindFlipped, composeKleisli, composeKleisliFlipped (Control.Bind) | Code. tools/style/src/Style/Parser.purs `bindNames` lists them; test/style.test.mjs `monadicNames` fixtures in every production module, failing first on `ap`; docs/engineering.md updated. |
| M2: test/depth.test.mjs hardcoded `const limit = 128` | It imports `nestingLimit` from output/Format.Parse.Grammar/index.js. |
| M3: src/Format/Parse/Literal.purs grew 51 to 55 lines against spec section 6 "no parser module grows" | Accepted in docs/progress.md: the growth is purs-tidy's one-per-line Grammar import list. |
| M4: the depth probe needs an uncommitted constant edit to re-run | Documented precisely in ADR 006 "Measurement" (set `nestingLimit = 1000000000`, build, run, restore, rebuild; never commit; test/depth.test.mjs fails while the edit is in place) and in the probe's header. No override reachable from the CLI or user programs was added. |
| M5: O001 lacked the Go build measurement and the parser accounting | O001 records the review's `go build` of a 10,000-deep nested `bumpusAdd` expression (2.3 s, correct, low risk) and that Grammar `chainLeft1`/`infixed` depth accounting must change with it. |

Generated Go is byte-identical: `node scripts/bumpus.mjs emit` of
examples/answer, shapes and tree `cmp` equal to bootstrap/*.go.
`rm -rf output && npm run verify` exit 0, 21 test files, 151 tests, 0
failures or skips, seven regression proofs
(.build/g001-final-fix-verify.log).

## Deferred minors (per-task ledger), triaged

The reviewer found every ledger item safe to leave deferred.

- Task 1: `spanned` on an empty production (fixed in Task 2: an empty span);
  `lastEnd` duplicating the previous token's end and an exactly-80-column
  signature: cosmetic, left.
- Task 2: frames per nesting level rose (recorded in E002 and ADR 006);
  the possible `foldAt` fast path and `between` primitive are optimizations,
  left; stale output of deleted modules is BACKLOG F006; a filtered RED log
  and an 83-character test line, left.
- Task 3: E005 timings lack a .build log (figures in E005); `rooted`'s
  reset was not shown failing first (the reviewer demonstrated its mutant
  fails); the hardcoded 128 is M2 above; frames per level not re-measured
  (disclosed in ADR 006).
- Task 4: wrong thresholds and the quadratic parameter check were fixed in
  Task 4b.
- Task 4b: wording carried to Task 5; constant-factor quadratic work in
  coverage (per-arm `take`, two-pass `specialize`, `Array.elem` in
  `complete`) stays under E002 (2); the `usefulHead` Maybe-Unit encoding
  disappeared with I1's rewrite; per-site mutant results unlogged, left.
- Task 5: O001 wording is M5 above; Cursor primitives are importable by
  name (the gate is name-based, review catches it); long unwrapped doc
  lines, left.
