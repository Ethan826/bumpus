# ADR 005: structural order and witness-format printing

Accepted and implemented 2026-10-07 (milestone A003). Binding spec:
docs/plans/2026-10-07-adt-printing-design.md. Verification is named per
decision; everything not named is proposed, not verified.

## Decisions

1. **One derived structural order, no user definitions.** Every type is
   comparable with `== != < <= > >=`. Declared types order by constructor
   declaration position, then fields left to right (first difference
   decides); Int by signed int32; Bool `false < true`. Derived, because the
   language has no strings, classes or polymorphism to define it otherwise
   (P001, C001). Checked by test/adt-order.test.mjs: explicit expected-order
   assertions plus an independent JS interpreter (test/value-oracle.mjs)
   whose three-way result must match Go for all six operators, including
   separately built equal values. Agreement with the oracle, not the order
   laws, is the acceptance check, since a reversed order also satisfies the
   laws. Regression rows `ctor-order` and `first-field` reintroduce each
   defect and must fail.
2. **Helpers for every declared type.** Format.Go.Compare emits
   `waxwingCmpN(a, b) int` and Format.Go.Show emits
   `waxwingShowN(out, v) []byte` per type in TypeId order, used or not (Go
   permits unused functions; the output stays simple and deterministic).
   Go `==` is never used on the structs: it would compare field pointers.
   A comparison on a declared type lowers to `waxwingCmpN(l, r) OP 0`.
3. **Bool helper on demand.** `waxwingCmpBool` is emitted only when a Bool
   ordering operator appears or a declared type has a Bool field
   (Format.Go.Usage), so programs without them keep their bytes:
   bootstrap/answer.go is unchanged by the milestone (tests: compare,
   adt-order).
4. **Witness-format printing.** `main` may return any type; the executable
   prints it with LF. Int decimal with `-`, Bool `true`/`false`, declared
   values `Name` or `Name(f1, f2)`: the coverage-witness format without `_`.
   Every printed value is a valid Waxwing expression under the same
   declarations; re-reading it is bounded by the nesting limit (ADR 006,
   G001): a printed list of more than 128 elements nests deeper than 128
   levels and is rejected with E_NESTING instead of recompiled (measured at
   the CLI: 128 elements compile, 129 give E_NESTING). Checked by the round
   trip in test/adt-print.test.mjs (recompile the text under the original
   declarations and print the same text; and the interpreter-parsed text
   equals the interpreter's original value), the `show-fields` regression
   row, and bootstrap/tree.go. E_ENTRY now covers only a missing `main`
   (`Expected fn main()`) and `main` with parameters.
5. **Malformed rule.** Comparing or printing panics with
   `waxwing: malformed value` on a visited nil field pointer or unknown tag.
   Comparison stops at the first difference, so later malformed fields may be
   unvisited; printing visits every field. Total order is claimed for
   well-formed values only; malformed values arise only from foreign code
   (I001). Checked by `malformed values panic only when visited`
   (test/adt-order.test.mjs: unknown tag and zero tag panic, a difference
   before the malformed field returns normally, equal prefixes reach the nil
   field and panic) and `printing a malformed value panics`
   (test/adt-print.test.mjs).
6. **Evaluation.** Operands evaluate strictly left then right with no short
   circuit (test/compare.test.mjs trace). Comparison is non-chaining and
   looser than `+`; chaining is E_SYNTAX `Comparisons do not chain`.

## Consequences

Each declared type adds two Go functions regardless of use. Go stacks grow,
so deep values compare and print (8192-element list). A user-defined order
or printer needs classes (C001) and would supersede decision 1.
