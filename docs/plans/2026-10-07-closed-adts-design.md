# Closed ADTs and exhaustive matching: design (A001)

Status: approved by the user 2026-10-07. Nothing here is implemented yet.
Approved in conversation: Go representation A (one tagged value struct per
type) with sequential first-match lowering; recursive types; nested patterns
with Maranget usefulness; `type`/`match` brace syntax; the uppercase rule and
the reserved words; coverage as a post-typecheck phase. The user's review
revisions (CtorId, nil guards, inhabitedness, witness policy) are folded in;
section 10 records each one.

## Goal and non-goals

Goal: monomorphic closed sum-of-products types, typed construction, nested
pattern matching with exhaustiveness and redundancy diagnostics, and
deterministic Go that builds and runs. It is a bounded milestone on Stage 0.

Non-goals: type parameters (P001), kinds (K001), records/field names (R001),
equality/ordering/printing of ADT values, deriving, guards, or-patterns,
as-patterns, empty matches, decision-tree compilation, FFI validation
(I001), and modules (M001). `main` still returns Int or Bool.

Preserved: Stage 0 phase boundaries, the `IR.Internal` allowlist discipline,
strict left-to-right evaluation, and `bootstrap/answer.go` bytes. Any Stage 0
program that does not use the new reserved words emits byte-identical Go.

## 1. Syntax and lexing

```ebnf
program     = { declaration } ;
declaration = typedecl | function ;
typedecl    = "type", upper, "=", ctor, { "|", ctor }, ";" ;
ctor        = upper, [ "(", type, { ",", type }, ")" ] ;
type        = "Int" | "Bool" | upper ;
expression  = "if", expression, "then", expression, "else", expression
            | "match", expression, "{", arm, { ",", arm }, [ "," ], "}"
            | addition ;
arm         = pattern, "=>", expression ;
pattern     = "_" | lower | upper, [ "(", pattern, { ",", pattern }, ")" ]
            | integer | "true" | "false" ;
upper       = identifier starting with "A".."Z" ;
lower       = identifier starting with "a".."z" or "_", other than "_" ;
```

The lexer adds the punctuation `|`, `{` and `}`, and the two-character token
`=>`, which is matched before the single `=`. New reserved words: `type`,
`match` and the lone `_`. This is a deliberate small break, because Stage 0
accepted all three as identifiers. ADR 003 records it.

Type and constructor names must be `upper`; otherwise E_SYNTAX at the name.
In a pattern, an `upper` name is always a constructor reference and a `lower`
name is always a binder, so a misspelled constructor cannot silently become a
catch-all. Function and parameter naming is unchanged from Stage 0.

Integer patterns use exactly the expression integer syntax and helper:
optional `-` token then digits, whitespace permitted, range-checked to int32
(E_INTEGER). `match` is an expression form at the same level as `if`, so it
must be parenthesized when it is an addition operand. A type with a field
list must have at least one field: `C()` is E_SYNTAX.

```text
type IntList = Nil | Cons(Int, IntList);
fn sum(xs: IntList): Int = match xs { Nil => 0, Cons(h, t) => h + sum(t) };
```

## 2. Resolution

Namespaces:

| Namespace | Members | Duplicate rule |
|---|---|---|
| Types | declared type names | E_DUPLICATE at the second type |
| Globals | functions and constructors together | E_DUPLICATE at the later declaration |
| Locals | parameters, then pattern binders | E_DUPLICATE within one parameter list or pattern |

Constructors are global across all types. `type A = X; type B = X;` is
E_DUPLICATE, and so is a constructor that shares a function's name.
`Cons(x, Cons(x, _))` is E_DUPLICATE; it is never an equality test. A binder
may shadow a parameter; its scope is its own arm body.

Types resolve in two passes. The first pass registers every type name and
assigns TypeId and CtorId in declaration order. The second resolves field and
signature types. So declaration order is free, and mutual recursion
(Tree/Forest) works. An unknown type name is E_UNBOUND at the reference.

Expression lookup:

- **A bare name:** local first (Stage 0), then a nullary constructor. Functions
  are not values; a bare function name stays E_UNBOUND, as in Stage 0.
- **A bare constructor that takes fields:** E_ARITY.
- **Call position `f(…)`:** a local is E_NOT_CALLABLE (Stage 0). Otherwise
  look up the shared global table: a function becomes a call; a constructor
  that takes fields becomes a construction; a nullary constructor is
  E_NOT_CALLABLE. A name in neither is E_UNBOUND.
- **A constructor in a pattern:** it must exist (E_UNBOUND) and its pattern
  must have exactly the constructor's field count (E_ARITY).

LocalIds: the parameters are numbered 0..n-1, then each binder gets the next
number in source pre-order across the function body. The result is
deterministic and independent of spelling.

A `main` whose result is a named type is E_ENTRY.

## 3. Types and checking

Syntax gets `TypeRef = IntRef | BoolRef | NamedRef Span String`. Resolved and
IR types become `Ty = TInt | TBool | TData TypeId`. The program carries a type
table:

```text
TypeInfo = { name :: String, ctors :: Array CtorId, span :: Span }
CtorInfo = { name :: String, owner :: TypeId, fields :: Array Ty, span :: Span }
```

Names are used only in diagnostic messages, never in generated Go. The
checked IR uses the constructor's identity, CtorId, and nothing about its
representation. The Go tag exists only in lowering (section 6).

Checking rules:

- **Construction:** exact arity (E_ARITY at the call), and each argument's
  type equals its field's type (E_TYPE at the argument). The result is
  `TData owner`.
- **Patterns** are checked against the expected type top-down. A constructor
  whose owner differs, or a literal of the wrong primitive type, is E_TYPE at
  the pattern. Binders take the expected type.
- **Arms** must all have the same type as the first arm (E_TYPE at the
  offending body), as `if` branches do. The match's type is that type.
- All expressions are checked, including unreachable arms, as in Stage 0.

## 4. Inhabitedness and coverage

Coverage is a pure phase, `Sprig.Check.Coverage`. `Sprig.Check` runs it after
the whole program type-checks, and it consumes checked IR.

Inhabitedness is the least fixed point: Int and Bool are inhabited; a
constructor is inhabited if all its field types are; a type is inhabited if
any of its constructors is. Uninhabited types such as `type T = C(T);` are
legal, but no finite value of them exists.

The algorithm is Maranget's usefulness algorithm U(P, q) over typed pattern
vectors. Literals are nullary heads: Bool has the heads `true` and `false`;
Int has unboundedly many. A head with an explicit constructor or literal
specializes syntactically. For a wildcard head, the column's signature is
complete when it contains every inhabited constructor of its type. Bool is
complete when both literals appear; Int is never complete. A type with no
inhabited constructors is vacuously complete, so a wildcard over it is
useless.

- **Redundancy:** arm i is redundant when U(arms 0..i-1, pattern i) is false.
  An arm naming an uninhabited constructor is not reported, because only
  earlier arms make an arm redundant.
- **Exhaustiveness:** the match is exhaustive when U(all arms, `_`) is false.

Diagnostic order: functions in declaration order, and matches in source
pre-order (outer before inner). For each match, report the first redundant arm
(E_REDUNDANT, at that arm's pattern span), then non-exhaustiveness
(E_NON_EXHAUSTIVE, at the whole match span). The first diagnostic stops
compilation, as in Stage 0.

Canonical witness (Maranget's algorithm I). For the first column of type τ,
with Σ the heads present:

1. **Complete Σ:** try each inhabited constructor in declaration order (Bool:
   `true`, then `false`) on the specialized matrix. The first witness found
   wins and is rebuilt as `C(w1, …, wn)`.
2. **Incomplete Σ:** take a witness from the default matrix. Its head is `_`
   when Σ is empty. Otherwise the head is the first inhabited constructor in
   declaration order that is missing from Σ, with every field `_` (Bool: the
   first of `true` and `false` that is missing; Int: the smallest
   non-negative integer not in Σ).

Rendering: `Nil`, `Cons(_, Nil)`, decimal Int with `-` for negatives,
`true`, `false`, `_`. Message: `Missing pattern: <witness>`. Redundancy
message: `Redundant match arm`.

## 5. Checked IR

New nodes in `Sprig.IR.Internal`:

```text
Node += Construct CtorId (Array Expr) | Match Expr (Array Arm)
Arm     = { pattern :: Pattern, body :: Expr, span :: Span }
Pattern = Pattern { ty :: Ty, span :: Span, shape :: Shape }
Shape   = Wildcard | Bind LocalId | IntLit Int | BoolLit Boolean
        | Ctor CtorId (Array Pattern)
```

`CheckedProgram` also carries the type table. There is no match numbering in
the IR; lowering numbers matches itself.

## 6. Go representation and lowering

Types and constructors are emitted after `sprigAdd` and before the functions,
only when the program declares types, so `answer.go` stays unchanged. The
Go tag is the constructor's 1-based index within its owner type. Tag 0 is
never produced.

```go
type sprigTy0 struct {
tag uint32
c1f0 int32
c1f1 *sprigTy0
}

func sprigCtor0() sprigTy0 { return sprigTy0{tag: 1} }

func sprigCtor1(f0 int32, f1 sprigTy0) sprigTy0 { return sprigTy0{tag: 2, c1f0: f0, c1f1: &f1} }
```

The struct has one field per constructor field, named `c<CtorId>f<index>`.
Primitive fields are stored directly. Each ADT field is a pointer: the
constructor receives the argument by value, which is a copy, and stores that
copy's address. Values are never mutated. Go evaluates call arguments in
lexical left-to-right order, so construction keeps strict source order.

Each match lowers to an immediately invoked function, like `if`. Within each
function, matches are numbered in source pre-order (`sprigMatch<k>`):

```go
func(sprigMatch0 sprigTy0) int32 {
if sprigMatch0.tag == 2 && sprigMatch0.c1f1 != nil && sprigMatch0.c1f1.tag == 1 {
sprigLocal1 := sprigMatch0.c1f0
_ = sprigLocal1
return …
}
if true { return … }
panic("sprig: unmatched value")
}(<scrutinee>)
```

Rules for each arm's condition:

- A constructor position tests its tag.
- Before any projection goes through a pointer field (a nested test, or a
  binder of ADT type, which binds `*field`), the condition tests that field
  `!= nil`. The conjuncts appear left to right in pattern pre-order, so `&&`
  short-circuiting guards every dereference.
- Literal positions compare against `int32(n)` or `true`/`false`.
- An irrefutable arm's condition is `true`.
- Each binder is followed by `_ = binder`, so Go never reports an unused
  variable.

Safety policy. Generated code never performs an unguarded nil dereference.
Malformed representations can only arise from Go code outside the language:
tag 0, a tag beyond the owner's constructors, or a nil pointer field under a
valid tag. Such a value is detected only where a match inspects the malformed
part. If no arm matches, the match reaches the unmatched panic, never a Go
runtime nil error. Wildcards and binders do not validate what they skip.
Deep validation at ingress belongs to I001. Values built in source are always
well-formed, so the panic is unreachable in an accepted program, and language
semantics never rely on it.

## 7. Diagnostics

| Code | New? | Trigger and span |
|---|---|---|
| E_SYNTAX | no | lowercase type/constructor name; `C()` declaration; malformed match |
| E_DUPLICATE | no | type; global (function/constructor); parameter; binder |
| E_UNBOUND | no | unknown type, constructor, or bare name |
| E_ARITY | no | construction or constructor pattern with the wrong field count |
| E_NOT_CALLABLE | no | a local, or a nullary constructor, in call position |
| E_TYPE | no | field argument; pattern type; arm body |
| E_ENTRY | no | `main` returns a named type |
| E_REDUNDANT | yes | first redundant arm's pattern |
| E_NON_EXHAUSTIVE | yes | whole match span; witness in the message |

The JSON wire names are `E_REDUNDANT` and `E_NON_EXHAUSTIVE`. `codeName` grows
to twelve arms. E003's exception is widened, not regrouped, and every code
keeps its own exact rejection fixture.

## 8. Verification

- **Executable examples:** an Int list sum; an expression-tree evaluator with
  nested patterns; Int/Bool literal matches with wildcard fallbacks; mutually
  recursive Tree/Forest types; a match nested in an arm.
- **Negative fixtures:** one per row of section 7, each asserting exact code,
  span, file name and exit status. Witness texts are pinned, including a
  nested `Cons(_, Nil)`, a Bool `false`, an Int `2` after the arms `0` and
  `1`, and a case where an uninhabited constructor is not offered as the
  witness.
- **Property: execution oracle.** Generated well-typed ADT programs run in Go
  and agree with the BigInt reference interpreter, extended with
  construction and first-match semantics.
- **Property: coverage oracle.** For generated small types and pattern sets,
  enumerate values up to maximum pattern depth + 1. Int values are the
  literals present plus one fresh value. Subtrees beyond the depth are opaque
  leaves of inhabited types, matched only by wildcards and binders. Coverage's
  exhaustive/redundant verdicts must equal the enumeration's, and each
  reported witness must cover only unmatched enumerated values. This oracle
  does not use Maranget's algorithm.
- **Representation:** a new emitted-bytes snapshot, `bootstrap/shapes.go`. An
  injected Go test calls lowered matches with `sprigTy0{}` and with a tag-2
  value whose recursive field is nil. Each must panic with exactly
  `sprig: unmatched value`, not a runtime error.
- **Regression mutation:** in an isolated copy, making exhaustiveness always
  succeed must fail the suite, and the healthy compiler must pass it. A
  second mutation that drops the nil guard must fail the representation test.
- **Stage 0:** all 19 existing tests pass unchanged, `answer.go` stays
  byte-identical, and `npm run verify` passes before completion.

## 9. Module layout and documentation

Every file stays at or under 250 lines. Expected new or split modules:
`Parse/Declaration`, `Parse/Pattern`, `Resolve/Types`, `Resolve/Pattern`,
`Check/Match`, `Check/Coverage` and `Go/Data`. The writing-plans step fixes
the exact files.

The structure gate's `IR.Internal` allowlist adds the new Check/* and Go/*
modules only, and its negative test still rejects other importers.

Documentation:

- ADR 003: representation, nil-guard safety policy, uppercase rule, reserved
  words, CtorId versus tag.
- `language.md`: grammar and semantics.
- `architecture.md`: the coverage phase and the type table.
- Provenance: conceptual influence of Maranget, "Warnings for pattern
  matching" (JFP 2007), with an independent implementation.
- Updates to the backlog (A001, E003), progress, and the plan index.

## 10. Review resolutions

- Bare function names are not expressions; functions resolve only in call
  position (section 2).
- Constructors store primitive arguments directly and ADT arguments as the
  address of a copy (section 6).
- Every pointer projection is nil-guarded; the malformed-value policy is
  explicit (section 6).
- Inhabitedness is computed; witnesses never name uninhabited constructors
  (section 4).
- Type resolution is two-pass, which makes mutual recursion work (section 2).
- Constructor names are global across types (section 2).
- Duplicate binders are E_DUPLICATE, never equality patterns (section 2).
- Integer patterns share the expression integer syntax, including negative
  literals (section 1).
- The witness selection policy is specified (section 4).
- The IR has no MatchId; lowering numbers matches (sections 5 and 6).
- The IR uses CtorId; the tag exists only in lowering (sections 3, 5 and 6).
- The panic is an impossible-state guard only (section 6).
