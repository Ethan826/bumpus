# ADT printing, equality and ordering: design (A003)

Status: design direction approved by the user 2026-10-07 with five
clarifications (entry errors, round trip, ordering tests, malformed values,
snapshot preservation), folded in below. The written spec was approved 2026-10-07.
Nothing here is implemented yet. Milestone item 1 (F004) is done.

## Goal and non-goals

Goal: `main` may return a value of any type and the executable prints it;
built-in comparison operators `==`, `!=`, `<`, `<=`, `>`, `>=` work on Int,
Bool and every declared type, with one total structural order.

Non-goals: user-defined printing or ordering (no strings, type classes or
polymorphism exist; P001), boolean connectives, chained comparisons,
decision-tree lowering (A002), full validation of foreign values (I001).

Preserved: phase boundaries and the IR.Internal allowlist; strict
left-to-right evaluation; `bootstrap/answer.go` bytes. Any program that
returns Int or Bool from `main`, uses no comparison and declares no types
emits byte-identical Go. `bootstrap/shapes.go` gains the per-type helpers
(section 5) and is regenerated with its diff reviewed.

## 1. Syntax and lexing

New tokens, longest match first: `==`, `!=`, `<=`, `>=`, `<`, `>`. `==` is
matched before `=>` and `=`. A lone `!` is E_LEX.

```ebnf
expression = "if", expression, "then", expression, "else", expression
           | "match", expression, "{", arm, { ",", arm }, [ "," ], "}"
           | comparison ;
comparison = addition, [ ( "==" | "!=" | "<" | "<=" | ">" | ">=" ),
             addition ] ;
```

Comparison binds looser than `+` (`a + 1 < b`), and does not chain:
`a < b < c` and `a == b == c` are E_SYNTAX at the second operator. `if` and
`match` remain at expression level, so they need parentheses as operands.
The span of a comparison runs from its left operand to its right operand.

## 2. Typing

Both operands are inferred, left then right; then the right operand must
have the left operand's type, else E_TYPE at the right operand (expected:
left type). Every type is comparable, including uninhabited ones. The
result is Bool.

Entry rules: E_ENTRY still reports a missing `main` and a `main` with
parameters. Only the result restriction disappears: `EntryResult` is removed
from `Domain.Problem.EntryKind`, and the missing-entry message changes from
`Expected fn main(): Int or Bool` to `Expected fn main()`. The existing
`type L = N; fn main(): L = N;` rejection row becomes a positive test that
prints `N`.

## 3. Semantics

Operands are evaluated strictly, left then right, before comparing; there is
no short-circuit. The order, on finite well-formed Bumpus values, is total:

- Int: signed int32 order. Bool: `false < true`.
- Declared types: constructors order by declaration position in their type;
  equal constructors compare fields left to right, and the first differing
  field decides (lexicographic). Nullary constructors with the same
  constructor are equal.
- `==` holds exactly when the order says equal; `!=` is its negation;
  `<=`, `>`, `>=` follow from the three-way result. Equality is structural:
  separately constructed equal values are equal (never pointer identity).

Malformed values (only possible from future foreign code, I001): comparing
or printing panics with `bumpus: malformed value` when it visits a nil field
pointer or an unknown tag. Comparison visits fields only until the first
difference, so later malformed fields may go unnoticed; printing visits
every field. Total ordering is claimed only for well-formed values.

## 4. Printing

The executable prints `main`'s value plus LF. Int prints decimal with a
leading `-` when negative; Bool prints `true` or `false`; a declared value
prints `Name` when nullary, else `Name(f1, f2)` with `, ` separators. This is
the coverage-witness format without `_`. Each printed value is a valid Bumpus
expression whose constructors resolve against the program's own type
declarations, since minus belongs to integer literals.

## 5. Go lowering

- Int and Bool equality use Go `==`/`!=`; Int ordering uses Go operators on
  int32. Bool ordering calls `bumpusCmpBool(a bool, b bool) int`.
- Each declared type N gets `bumpusCmpN(a bumpusTyN, b bumpusTyN) int`
  (returns -1, 0 or 1; compares tags as declaration positions, then fields)
  and `bumpusShowN(out []byte, v bumpusTyN) []byte` (uses `fmt.Append` and
  `append`, so the import list is unchanged). A comparison on N lowers to
  `bumpusCmpN(left, right) OP 0`. Go `==` is never used on the structs: it
  would compare field pointers.
- Helpers for every declared type are emitted in TypeId order, whether or
  not used: simple and deterministic, and Go allows unused functions.
- `bumpusCmpBool` is emitted only when the program uses a Bool ordering
  operator or a declared type has a Bool field, so `answer.go` is unchanged.
- `main` for Int or Bool stays `fmt.Println(bumpusFnK())`; for type N it is
  `fmt.Println(string(bumpusShowN(nil, bumpusFnK())))`.
- Helpers recurse; Go stacks grow, and the existing 8192-element list test
  is extended to print and compare such a list.

Comparisons are a new IR node `Compare Operator Expr Expr`, where
`Operator` is a closed ADT in Domain (Equal, NotEqual, Less, LessEqual,
Greater, GreaterEqual). Format.Go prints it; no target detail enters IR.

## 6. Diagnostics

New Problem constructors are not needed: syntax errors reuse `Syntax`,
type errors `TypeMismatch`. The diagnostics characterization updates
the missing-entry message and drops the EntryResult family; every other
family keeps its exact code, span and text.

## 7. Tests and proofs

- Syntax/rejection rows with exact code and span: each operator parses;
  chaining is E_SYNTAX at the second operator; `!` alone is E_LEX; operand
  type mismatch is E_TYPE at the right operand; `if`/`match` operands need
  parentheses.
- Explicit expected-order assertions executed in Go: constructor
  declaration order (`Nil < Cons(0, Nil)` for `type L = Nil | Cons(Int,
  L)`), first differing field decides (`Cons(1, Nil) > Cons(0, Cons(5,
  Nil))`), Int sign (`-1 < 0`), `false < true`, and separately constructed
  equal values from two different functions compare `==` and not `<`.
- Oracle: an independent JS interpreter computes the three-way order of
  generated value pairs (including equal pairs built separately) over
  generated type systems; one Go program per seed evaluates all six
  operators per pair and must agree. The same run checks the order laws
  (reflexive, antisymmetric, transitive, total) on the interpreter results,
  but agreement with the interpreter is the acceptance check, because a
  reversed constructor order also satisfies every law.
- Print round trip: for generated well-typed values, the program prints
  text T. (a) Recompiling with the original declarations and result type,
  `fn main(): R = T;`, prints T again. (b) T, evaluated by the independent
  interpreter, is structurally equal to the interpreter's value of the
  original expression, so a printer that drops or reorders fields fails
  even when (a) holds.
- Regression rows (scripts/regression.mjs, isolated copies): `ctor-order`
  reverses tag comparison in bumpusCmpN and must fail the expected-order
  assertion; `first-field` compares the last field first and must fail
  it; `show-fields` drops all but the first field when printing and must
  fail the round-trip probe.
- Snapshots: answer.go byte-identical; shapes.go regenerated and reviewed;
  a new example returning a declared value gets its own snapshot.

## 8. Documentation

docs/language.md (grammar, comparison and printing semantics, entry rule),
ADR 005 (structural order and printing format), architecture.md (Compare
node and helpers), BACKLOG (A003 Done; any new follow-ups), progress and
findings, next-session.
