module Format.Parse.Block (block, parenthesized) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe, maybe')
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( Diagnostic
  , Expr(..)
  , Item(..)
  , Position
  , Span
  , exprSpan
  , problemAt
  )
import Format.Lex (Token)
import Format.Parse.Grammar
  ( Parser
  , dispatch
  , expect
  , name
  , on
  , refine
  , sepByTrailing1
  , spanned
  , token
  )

-- An item and where its last consumed token ends, which may be past its
-- expression's span (a closing parenthesis).
type Ended = { item ∷ Item, end ∷ Int }

-- The items and where the list ends: at its trailing `;`, if any.
type Listed = { items ∷ Array Ended, end ∷ Int }

-- A parenthesized expression, or `()`, and where its source starts.
type Grouped = { value ∷ Expr, start ∷ Position }

-- FX001 design §1: `{}` is `()`; otherwise items separated by `;`, each
-- `let name = e`, `let _ = e` or `e`. The last item is the value, unless
-- a `;` follows it, which discards it and makes the value `()` at the
-- closing `}` (Domain.Syntax `Item`); a `let` must be followed by `;`.
-- Every expression is nested, as an `if` branch is (ADR 006).
block ∷ Parser Expr → Parser Expr
block inner = refine identity
  ( blockOf <$> expect "{"
      <*> dispatch [ on "}" (pure Nothing) ] (Just <$> listed inner)
      <*> expect "}"
  )

-- `(e)`, which leaves no node, or `()`, the Unit value, spanning both
-- parentheses. Either starts at its `(` (Format.Parse.Expression).
parenthesized ∷ Parser Expr → Parser Grouped
parenthesized inner = groupedOf <$> expect "("
  <*> dispatch [ on ")" (Left <$> token) ] (Right <$> inner <* expect ")")
  where
  groupedOf open found =
    { value: either (unitBetween open) identity found
    , start: open.span.start
    }
  unitBetween open close =
    UnitValue { start: open.span.start, end: close.span.end }

listed ∷ Parser Expr → Parser Listed
listed inner = spanned listOf (sepByTrailing1 ";" "}" (spanned ended one))
  where
  one = item inner
  ended span found = { item: found, end: span.end.offset }
  listOf span items = { items, end: span.end.offset }

item ∷ Parser Expr → Parser Item
item inner = dispatch [ on "let" (letItem inner) ] (Discard <$> inner)

letItem ∷ Parser Expr → Parser Item
letItem inner = letOf <$> expect "let" <*> binder <* expect "=" <*> inner
  where
  letOf keyword bound value =
    Let { start: keyword.span.start, end: (exprSpan value).end } bound value

binder ∷ Parser (Maybe String)
binder = dispatch [ on "_" (Nothing <$ token) ] (Just <<< textOf <$> name)
  where
  textOf found = found.text

blockOf ∷ Token → Maybe Listed → Token → Either Diagnostic Expr
blockOf open contents close = maybe (Right (UnitValue span))
  (filled span close)
  contents
  where
  span = { start: open.span.start, end: close.span.end }

-- A `;` after the last item ends the list past that item's own end.
-- sepByTrailing1 reads at least one item, so `split` always runs.
filled ∷ Span → Token → Listed → Either Diagnostic Expr
filled span close found = maybe' none split (Array.unsnoc found.items)
  where
  none _ = Right (UnitValue span)
  split parts
    | parts.last.end /= found.end = Right
        (Block span (map itemOf found.items) (UnitValue close.span))
    | otherwise = valued span close (map itemOf parts.init) parts.last.item
  itemOf ended = ended.item

valued ∷ Span → Token → Array Item → Item → Either Diagnostic Expr
valued span close items = case _ of
  Discard value → Right (Block span items value)
  Let _ _ _ → Left (problemAt (Syntax "Expected ;") close.span)
