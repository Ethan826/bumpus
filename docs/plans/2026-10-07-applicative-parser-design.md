# Applicative parser and depth limit: design (G001)

Status: written 2026-10-07, awaiting user review. Nothing is implemented.
User decisions: the parser abstraction is applicative only (no Monad
instance); deep nesting gets a depth limit with a structured diagnostic
instead of a raw stack trace (option 1 of three discussed; heap-based
phases are recorded as a backlog item, not done here).

## Goal and non-goals

Goal: replace hand-threaded parser state (`{ value, rest }` passed between
steps) with a small applicative `Parser` type, so the remaining input is
threaded in exactly one place; make every list in the grammar stack-safe;
reject over-deep nesting with a structured diagnostic; replace the
resolver's hand-threaded `next` LocalId counter with a small state type.

Non-goals: new syntax, better error messages ("expected one of …"), error
recovery, heap-based traversal of later phases, performance work beyond
keeping parsing linear. Every accepted program produces byte-identical Go,
and every existing diagnostic keeps its exact code, span and message.

## 1. The Parser type (Format.Parse.Core)

```purescript
newtype Parser a = Parser (State → Either Diagnostic { value ∷ a, rest ∷ State })
```

Instances: Functor, Apply, Applicative. No Bind, Monad, Alt or MonadRec
instance: a production cannot depend on an earlier parsed value, and there
is no backtracking. `State` keeps today's fields (tokens, index, eof) plus
`depth ∷ Int` (section 4). Recursive productions use a local
`defer ∷ (Unit → Parser a) → Parser a`, since PureScript is strict.

Primitives (the only code that touches `State`): `token` (any token),
`expect text`, `name`, `upperName`, `typeRef`, `peek`-based choice, and
`failWith message` (E_SYNTAX at the current token, or at end of input, exactly
as `failAt` does today).

Choice is predictive, LL(1), on the next token's text:

```purescript
dispatch ∷ Array (Case a) → Parser a → Parser a   -- first matching case, else fallback
on ∷ String → Parser a → Case a                    -- exact token text
when ∷ (String → Boolean) → Parser a → Case a      -- token predicate
optionalOn ∷ String → Parser a → Parser (Maybe a)  -- parse iff next token is text
```

`Case` is a record of a predicate and a parser (Data.Tuple is not on the
pure-layer allowlist). This reproduces every `if peek … then … else …`
decision in the current parser without backtracking.

Lists, all stack-safe (`tailRecM` over `Either` internally, accumulating with
Format.Stack, so linear time):

```purescript
sepBy1 ∷ String → Parser a → Parser (Array a)          -- a (sep a)*
sepByAllowTrailing1 ∷ String → String → Parser a → Parser (Array a)
  -- match arms: optional trailing separator before the closing token
commaList ∷ Parser a → Parser (Array a)                 -- empty iff next is ")"
chainLeft1 ∷ String → (a → a → a) → Parser a → Parser a -- `+` chains
```

`chainLeft1` folds left inside a loop, producing the same left-nested `Add`
tree as today.

## 2. Spans

Spans stay byte-identical. Two rules exist today and both are kept:
token spans (a literal, a name, `if … else e` from the `if` token to the end
of `e`, `match … }` to the closing brace, a constructor pattern to its `)`)
and child spans (an operator node runs from its left operand's start to its
right operand's end, so `(1) + 2` starts at `1`; parentheses return the inner
expression unchanged). Two helpers express them:

```purescript
spanned ∷ (Span → a → b) → Parser a → Parser b   -- first to last consumed token
```

and the existing `spanBetween` for child-derived spans. Each production
uses the rule it uses today; the diagnostics characterization, the
200-tree roundtrip and the whitespace-prefix property are the safety net.
`State` tracks the end of the last consumed token for `spanned`.

## 3. Productions

All of Format.Parse.{Literal, Pattern, Expression, Declaration} and the
declaration loop in Format.Parse are rewritten in applicative style, e.g.

```purescript
ctorPattern = ctorOf <$> upperName <*> optionalOn "(" (parens (sepBy1 "," pattern))
expression = dispatch [ on "if" conditional, on "match" matchExpression ] comparison
```

Comparisons keep "Comparisons do not chain" (E_SYNTAX at the second
operator): after one operator, a case on the next token fails with that
message. Port order: Pattern first (smallest), then Literal, Expression,
Declaration, and the top-level loop; each step keeps the full suite green.

## 4. Depth limit

Nesting depth is counted in the parser: entering any nested expression,
pattern or argument position increments `State.depth` (a parenthesized
expression, an `if` branch or condition, a `match` scrutinee or arm body, a
call or constructor argument, a nested pattern, and each `+` or comparison
operand). A `+` chain counts as its AST depth, because later phases recurse
over the left-nested `Add` tree.

Past the limit, compilation fails with a new error code `E_NESTING`
(ErrorCode `NestingLimit`, Problem `NestingTooDeep Int`) at the token that
would exceed it, message `Nesting exceeds <limit> levels`. The limit is a
named constant in Format.Parse.Core.

Choosing the limit: measure, after the rewrite, the smallest depth at which
any phase (parse, resolve, check, coverage, Go emission) overflows in a cold
`node scripts/bumpus.mjs emit` process, for each nesting form. The limit is a
power of two at most half of that minimum; 256 is expected. Tests: for each
form, depth = limit compiles, emits and (where executable) runs through the
CLI; depth = limit + 1 is E_NESTING with exact span; the CLI never prints a
raw stack trace for these inputs.

docs/language.md states the rule; ADR 006 records the choice and the three
options considered (limit, larger Node stack, heap-based phases), and
BACKLOG gets a Planned row for heap-based phases.

## 5. Resolver numbering

The resolver threads `next ∷ Int` by hand through every expression and
pattern (`first.next`, `predicate.next`). Unlike parsing, resolution has a
genuine data dependency: a pattern's binders form the scope of its arm body.
So the resolver gets a small state-and-error type with Functor, Apply,
Applicative and Bind:

```purescript
newtype Fresh a = Fresh (Int → Either Diagnostic { value ∷ a, next ∷ Int })
fresh ∷ Fresh LocalId
```

Binders are still numbered in source pre-order; LocalIds, and therefore
generated Go, are unchanged. Arms and argument lists use `traverse`, which is
stack-safe for long arrays (balanced). This reuses one `Fresh` for patterns
and expressions and removes `Numbered` threading from Domain.Resolved's
public surface if nothing else needs it.

## 6. Acceptance

- Every row of test/diagnostics.test.mjs and every rejection test unchanged
  (code, span, message); all snapshots and CLI emits byte-identical (cmp).
- 200-tree roundtrip, whitespace-prefix and large-source tests pass; the
  E002 breadth inputs (1,536 constructors, 1,536 fields, 1,793 arguments,
  1,473 arms) compile, each in a new time-bounded test seen failing first.
- Depth-limit tests per section 4, seen failing first (raw RangeError).
- A regression row restores a hand-threaded state mistake (a production
  that returns the state before its last token) and must be caught.
- No parser module grows; the CST style gate passes with no new exceptions.
- E002 narrows to the remaining per-reference name lookups (or closes if
  G001 also fixes them; out of scope here).
