module Format.Parse.Expression (expression) where

import Prelude
import Data.Either (Either(..))
import Data.Maybe (Maybe, maybe)
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( Diagnostic
  , Expr(..)
  , Operator(..)
  , Span
  , exprSpan
  , problemAt
  )
import Format.Lex (Token, isName)
import Format.Parse.Grammar
  ( Case
  , Parser
  , chainLeft1
  , commaList
  , defer
  , dispatch
  , expect
  , failWith
  , infixed
  , name
  , nested
  , on
  , onWhen
  , optionalOn
  , refine
  , spanned
  , token
  )
import Format.Parse.Literal (integerLiteral, integerStart)
import Format.Parse.Pattern (arms)

type Comparison = { text ∷ String, operator ∷ Operator }

comparisons ∷ Array Comparison
comparisons =
  [ { text: "==", operator: Equal }
  , { text: "!=", operator: NotEqual }
  , { text: "<", operator: Less }
  , { text: "<=", operator: LessEqual }
  , { text: ">", operator: Greater }
  , { text: ">=", operator: GreaterEqual }
  ]

-- PureScript is strict, so the productions below receive `inner`, which
-- reaches `expression` lazily, rather than naming `expression` themselves.
-- Every use of `inner` is a nested position (ADR 006): a parenthesized
-- expression, an `if` condition or branch, a `match` scrutinee or arm body,
-- or a call or constructor argument.
expression ∷ Parser Expr
expression = dispatch
  [ on "if" (conditional inner), on "match" (matchExpression inner) ]
  (comparison inner)
  where
  inner = nested (defer later)
  later _ = expression

-- Comparison is non-associative: one operator between two additions, and
-- E_SYNTAX at a second operator. Both operands are one level deeper.
comparison ∷ Parser Expr → Parser Expr
comparison inner = (#) <$> additive inner
  <*> dispatch (map (rightOperand inner) comparisons) (pure identity)

rightOperand ∷ Parser Expr → Comparison → Case (Expr → Expr)
rightOperand inner comparing = on comparing.text
  (compareTo <$ infixed token <*> nested (additive inner) <* unchained)
  where
  compareTo right left =
    Compare (spanBetween left right) comparing.operator left right

unchained ∷ Parser Unit
unchained = dispatch (map chained comparisons) (pure unit)
  where
  chained comparing = on comparing.text
    (failWith "Comparisons do not chain")

-- Operator nodes span their operands, so `(1) + 2` starts at `1`.
spanBetween ∷ Expr → Expr → Span
spanBetween first second =
  { start: (exprSpan first).start, end: (exprSpan second).end }

additive ∷ Parser Expr → Parser Expr
additive inner = chainLeft1 "+" add (atom inner)
  where
  add left right = Add (spanBetween left right) left right

conditional ∷ Parser Expr → Parser Expr
conditional inner = ifOf <$> expect "if" <*> inner <* expect "then" <*> inner
  <* expect "else"
  <*> inner
  where
  ifOf keyword condition yes no =
    If { start: keyword.span.start, end: (exprSpan no).end } condition yes no

-- `match` is not an atom, so as an addition operand it needs parentheses.
matchExpression ∷ Parser Expr → Parser Expr
matchExpression inner = matchOf <$> expect "match" <*> inner <* expect "{"
  <*> arms inner
  <*> expect "}"
  where
  matchOf keyword scrutinee matched close =
    Match { start: keyword.span.start, end: close.span.end } scrutinee matched

-- Parentheses return the inner expression with its own span.
atom ∷ Parser Expr → Parser Expr
atom inner = dispatch
  [ on "(" (expect "(" *> inner <* expect ")")
  , on "true" (boolean true <$> token)
  , on "false" (boolean false <$> token)
  , onWhen integerStart (integer <$> integerLiteral)
  , onWhen isName (named inner)
  ]
  (refine notAnExpression token)
  where
  boolean value found = Boolean found.span value
  integer literal = Integer literal.span literal.value

-- Reached past the last token too, where taking reports the missing token.
notAnExpression ∷ Token → Either Diagnostic Expr
notAnExpression found =
  Left (problemAt (Syntax "Expected an expression") found.span)

-- A variable spans its name; a call runs through its `)`.
named ∷ Parser Expr → Parser Expr
named inner = spanned namedOf (parts <$> name <*> optionalOn "(" arguments)
  where
  parts identifier found = { identifier, arguments: found }
  arguments = expect "(" *> commaList inner <* expect ")"

namedOf
  ∷ Span → { identifier ∷ Token, arguments ∷ Maybe (Array Expr) } → Expr
namedOf span found = maybe (Variable span found.identifier.text)
  (Call span found.identifier.text)
  found.arguments
