# A001 final whole-branch review

Range c2a9788..69f6585 on main, reviewed 2026-10-07 against
docs/plans/2026-10-07-closed-adts-design.md and
docs/plans/2026-10-07-five-layers-design.md. Findings fixed in COMMIT.

## Verdict

Ready to merge with fixes. No Critical findings, one Important, seven Minor.

## What the reviewer probed

- 12k coverage-oracle cases, including the strict witness condition (a
  witness covers only unmatched enumerated values);
- 400 random type systems for inhabitedness;
- Go build and run of Tree/Forest, nested and scrutinee matches, ADT binders,
  ADT-returning functions and ADT-typed `if`;
- declaration-ordering edge cases, coverage performance (5-16 ms per case);
- the closing evidence log .build/a001-final.log (cold build, 0 warnings).

## Findings and resolution

| Finding | Resolution |
|---|---|
| Important 1: `npm run verify` can be green over a promoted strict warning (F004, incremental build) | AGENTS.md: until F004 is fixed, completion evidence is `rm -rf output && npm run verify`; docs/engineering.md states it as a review convention. F004 stays open; its row names the build.mjs fix as the next milestone's first item. |
| Minor 1: coverage oracle checked that *some* witness value is unmatched | test/coverage.test.mjs requires the witness to match at least one enumerated value and only unmatched ones (spec section 8). Passed unchanged. |
| Minor 2: oracle used one fixed, fully inhabited type | New test generates 120 small type systems (up to 3 types, 3 constructors, 2 fields) with uninhabited constructors; inhabitedness is brute-forced. Listing every constructor is exhaustive; dropping an inhabited one is E_NON_EXHAUSTIVE with exactly that constructor as witness; dropping an uninhabited one stays exhaustive. A mutant offering uninhabited constructors fails it; the old oracle passed that mutant. |
| Minor 3: function-first name clash reported at the later constructor | Fixed (ruling R7): Features.Resolve.Types reports a function/constructor clash at the earliest declaration by span offset, whatever its kind. New rejectedAt case `fn A(): Int = 1; type T = A;` failed before the fix (offset 26, the constructor) and passes after (the `fn A(): Int = 1;` span). |
| Minor 4: generated programs only had two-arm matches | test/adt-properties.test.mjs adds 8 generated flat matches of 3-5 arms (seed asserted to reach a third arm and the `_` tail). A lowering mutant that reorders arms after the second fails it; the nested test passes that mutant. |
| Minor 5: verify hard-coded the test list | scripts/verify.mjs reads every test/*.test.mjs from the directory. An unlisted failing dummy file made verify exit 1, then was removed. |
| Minor 6: over-long line in ADR 003 decision 9 | Rewrapped. |
| Minor 7: usefulness rows longer than the type vector counted as matched | `specialize` and `checkCtor` now return E_INTERNAL on a field-count mismatch instead of truncating. A direct test (test/diagnostics.test.mjs) fails with either change reverted; valid programs, the coverage tests and the oracle are unchanged. |

## Triage of deferred items

All were accepted as backlog except the F004 AGENTS.md line (Important 1).

- F005 (stale temp directories): backlog; a leak needs a timed-out probe.
  The next action is to move the probe directory under .build/regression.
- Stringly host codes: A005. Maranget worst case: A002.
- ADT-returning functions and ADT-typed `if` worked in the probe; now tested
  in test/adt-types.test.mjs.
- `type Int = A;` / `type Bool = A;` are E_SYNTAX: documented in
  docs/language.md and pinned in test/adt-types.test.mjs.
- The duplicated `second` program (test/adt-match.test.mjs and
  test/regression.mjs) now has cross-reference comments.
- Coverage attributes a Signature failure to the first function's span; a
  comment in Features/Check/Coverage.purs explains why.

Declined to judge: the CheckedProgram alias, Go operand-read order, E_SYNTAX
wording for `type Int`, the empty run destination quirk, UTF-16 offsets
(ADR 004), and historical names in the plan header.
