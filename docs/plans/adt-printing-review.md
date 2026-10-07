# A003 final whole-branch review

Range 74e5c2a..b5dde4e on branch a003, reviewed 2026-10-07 against
docs/plans/2026-10-07-adt-printing-design.md and ADR 005. Findings fixed in
one wave, commit `fix: address A003 final review`.

## Verdict

With fixes: three Important findings (two documentation overclaims, one
quadratic Go emission), five Minor findings selected for the fix wave, and
the per-task deferred minors triaged below.

## Findings and resolution

| Finding | Resolution |
|---|---|
| I1: the print round trip was overclaimed; the lowest crash threshold was unrecorded (constructor nesting overflows the parser at about 420-450 levels in a cold process; the CLI dies with a raw JS stack trace) | Documentation. BACKLOG E002 now states the cold-process constructor figure (re-measured at the CLI: 416 levels compile, 417 crash, exit 1, raw `RangeError` stack trace, no JSON diagnostic), keeps 1,536 parentheses, 2,048 `+` operands and 1,025 `if`s qualified as warm-process figures, and records the CLI behavior. docs/language.md and ADR 005 decision 4 now say printed values reproduce themselves under the same declarations and that re-reading is bounded by E002. |
| I2: "source length alone does not overflow" was false; breadth crashes (about 1,536 constructors, 1,536 fields, 1,793 call arguments, 1,473 match arms) | Documentation. docs/architecture.md says long declaration sequences and whitespace do not overflow, while deep nesting and long comma, constructor or arm lists inside one declaration still do. E002 lists the breadth figures; its next action is G001's `tailRecM` list combinators for breadth and an explicit depth limit reported as a structured Diagnostic for nesting. Neither crash is fixed in A003. |
| I3: Go emission quadratic in declared types (Show scanned all constructors per type; Compare and Data called `tagOf`, O(types), per constructor) | Code. New Format.Go.Layout builds once per program a tag table indexed by CtorId and each type's members (id, tag, CtorInfo) in declaration order, joined to the constructor table by sorting rather than lookup; Format.Go.emit passes it to Data, Compare, Show and Match. The resolver's `uniqueTypes` and `uniqueCtors` now use Features.Resolve.Repeated (the first repeated constructor alone searches for the earliest clashing declaration), and `typeInfo`, which filtered all constructors per type, numbers each type's constructor run from prefix sums. New test: 20,000 `type T<i> = C<i>;` plus `fn main(): Int = 0;` must compile within 5 s: 25.9-26.3 s before (failed), 0.23-0.28 s after. A large-count duplicate test (type, constructor, function-before-constructor among 20,000 types, also bounded at 5 s) failed that bound at 21.8 s when the final test file ran against a b5dde4e build (the types test failed there at 25.9 s), and takes 0.43 s after; reporting at the repeated constructor instead of the earliest declaration fails it and adt-types in an isolated copy. Emitted Go is byte-identical: `cmp` of answer, shapes and tree against bootstrap/*.go, and 504 programs (500 generated type systems with a comparison, a match and a printed main, the three examples and a nested-pattern program) emit identical bytes from b5dde4e and the fix. |
| M1: docs/language.md:57 (118 columns) and glued README lines | Reflowed, with the other long prose lines from A003 edits (README, language.md printing paragraph, architecture.md). README:2 is the logo `<img>` tag, left as is. |
| M2: the Compare unknown-tag check was tested only with tag 0 | test/adt-order.test.mjs adds `bumpusCmp0(bumpusTy0{tag: 3}, bumpusTy0{tag: 3})` for the two-constructor list, which must panic. Emitting the off-by-one `.tag > 3` (count + 1) instead of `.tag > 2` through goTest's transform makes it fail with `no panic`, while the tag-0 case still passes under that mutant. |
| M3: Compare.ctorFields `maybe ""` turned a missing CtorInfo into "fields equal" | Removed with I3: Compare, Data and Show iterate Layout members, which carry their CtorInfo, so none of them looks up a constructor. Match's `tagOf` keeps a 0 fallback, which never names a constructor (tags are 1-based). |
| M4: adt-order and adt-print kept the 2,000-character budget and per-seed program split after the lexer fix | Removed. Each adt-order seed is one Go program (2,392-3,189 characters), adt-print drops the budget assertion; every assertion is otherwise unchanged. No deviation note was needed. |
| M5: this record had to exist before A003 is Done | This file. A003 is Done in BACKLOG and the plan status. |

Also in the wave: test/coverage-oracle.mjs `lowBits` is renamed
`discardedLowBits` (it is the shift count), the 20,000-function test now
bounds its compile step at the same 5 s (0.27 s at b5dde4e, 0.25-0.29 s
after; the Go build is not timed), BACKLOG G001 records
the user's decision to do applicative parser combinators first after the
merge, BACKLOG E002 records the remaining linear-per-reference name
lookups (`resolveType`, `findGlobal`, constructor patterns: 1.7 s at 20,000
references; deferred to G001's resolver rework because the allowlist has no
map), and the regression row `first-field` follows the renamed
`member.ctor.fields`.

## Deferred minors from the per-task reviews

Fixed in this wave: the unbounded 20,000-declaration test (Task 3b), the
quadratic `uniqueTypes`/`uniqueCtors` and the E002 overclaim (Task 3b), the
`lowBits` name (Task 3b), "reproduces itself" without "under the same
declarations" (Task 4), glued lines and the long plan status line (Task 4),
and this review record (Task 4).

Still deferred, each with its reason:

- The tree snapshot test lives in adt-print rather than beside shapes in
  adt-match (Task 3): placement only; it runs and pins bytes either way.
- The round trip's `nested` regex does not prove three-level nesting, and no
  seed is asserted to contain a negative Int or a Bool field (Task 3): the
  interpreter equality on every seed already checks those values exactly;
  stronger seed preconditions belong with T001's test rework.
- `entryMain` emits nothing if the entry id is missing (Task 3): the
  resolver guarantees exactly one entry, and a missing `main` fails `go
  build` loudly.
- value-oracle `parseValue` does not check a closing `)` (Task 3): it is a
  test oracle whose output is compared with the printer's text exactly.
- BACKLOG R002 sits above R001, and dated progress entries name old `.sprig`
  paths (Task 3a): historical text kept verbatim by the rename ruling.
- The alternation test rules out strict alternation for one seed only (Task
  3b): the fix reads the high bits by construction; more seeds add little.
