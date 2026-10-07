module Format.Parse.Expression (expression) where

import Prelude
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), isJust, maybe')
import Format.Lex (Token)
import Format.Lex as Lex
import Domain.Syntax as Model
import Format.Parse.Core as Core
import Domain.Syntax (Expr(..), Operator(..), exprSpan)
import Format.Parse.Core (Parser, commaList, expect, failAt, name, peek, take)
import Format.Parse.Literal (integerLiteral, integerStart)
import Format.Parse.Pattern (arms)

expression ∷ Parser Expr
expression state = case peek state of
  "if" → conditional state
  "match" → matchExpression state
  _ → comparison state

-- Comparison is non-associative: one operator between two additions.
comparison ∷ Parser Expr
comparison state = additive state >>= operatorAfter

operatorAfter ∷ Core.Parsed Expr → Either Model.Diagnostic (Core.Parsed Expr)
operatorAfter first = maybe' alone (extendComparison first)
  (operatorOf (peek first.rest))
  where
  alone _ = Right first

extendComparison
  ∷ Core.Parsed Expr → Operator → Either Model.Diagnostic (Core.Parsed Expr)
extendComparison first operator = do
  token ← take first.rest
  second ← additive token.rest
  when (isJust (operatorOf (peek second.rest)))
    (failAt second.rest "Comparisons do not chain")
  pure
    { value: Compare (spanBetween first.value second.value) operator
        first.value
        second.value
    , rest: second.rest
    }

spanBetween ∷ Expr → Expr → Model.Span
spanBetween first second =
  { start: (exprSpan first).start, end: (exprSpan second).end }

operatorOf ∷ String → Maybe Operator
operatorOf = case _ of
  "==" → Just Equal
  "!=" → Just NotEqual
  "<" → Just Less
  "<=" → Just LessEqual
  ">" → Just Greater
  ">=" → Just GreaterEqual
  _ → Nothing

additive ∷ Parser Expr
additive state = do
  first ← atom state
  addition first

addition
  ∷ { value ∷ Expr, rest ∷ Core.State }
  → Either Model.Diagnostic (Core.Parsed Expr)
addition first =
  if peek first.rest /= "+" then Right first
  else extendAddition first

extendAddition ∷ Core.Parsed Expr → Either Model.Diagnostic (Core.Parsed Expr)
extendAddition first = do
  operator ← expect "+" first.rest
  second ← atom operator.rest
  addition
    { value: Add (spanBetween first.value second.value) first.value
        second.value
    , rest: second.rest
    }

conditional ∷ Parser Expr
conditional state = do
  keyword ← expect "if" state
  condition ← expression keyword.rest
  thenToken ← expect "then" condition.rest
  yes ← expression thenToken.rest
  elseToken ← expect "else" yes.rest
  no ← expression elseToken.rest
  pure
    { value: If
        { start: keyword.value.span.start, end: (exprSpan no.value).end }
        condition.value
        yes.value
        no.value
    , rest: no.rest
    }

-- `match` is not an atom, so as an addition operand it needs parentheses.
matchExpression ∷ Parser Expr
matchExpression state = do
  keyword ← expect "match" state
  scrutinee ← expression keyword.rest
  open ← expect "{" scrutinee.rest
  matched ← arms expression open.rest
  close ← expect "}" matched.rest
  pure
    { value: Match
        { start: keyword.value.span.start, end: close.value.span.end }
        scrutinee.value
        matched.value
    , rest: close.rest
    }

atom ∷ Parser Expr
atom state = case peek state of
  "(" → parenthesized state
  "true" → boolean true state
  "false" → boolean false state
  text
    | integerStart text → integer state
    | otherwise → namedOrInvalid state

parenthesized ∷ Parser Expr
parenthesized state = do
  open ← expect "(" state
  inside ← expression open.rest
  close ← expect ")" inside.rest
  pure { value: inside.value, rest: close.rest }

integer ∷ Parser Expr
integer state = do
  literal ← integerLiteral state
  pure
    { value: Integer literal.value.span literal.value.value
    , rest: literal.rest
    }

boolean ∷ Boolean → Parser Expr
boolean value state = do
  token ← take state
  pure { value: Boolean token.value.span value, rest: token.rest }

namedOrInvalid ∷ Parser Expr
namedOrInvalid state = do
  token ← take state
  if Lex.isName token.value.text then named state
  else failAt state "Expected an expression"

named ∷ Parser Expr
named state = do
  identifier ← name state
  if peek identifier.rest /= "(" then namedVariable identifier
  else namedCall identifier

namedVariable
  ∷ Core.Parsed Token → Either Model.Diagnostic (Core.Parsed Expr)
namedVariable identifier = pure
  { value: Variable identifier.value.span identifier.value.text
  , rest: identifier.rest
  }

namedCall ∷ Core.Parsed Token → Either Model.Diagnostic (Core.Parsed Expr)
namedCall identifier = do
  open ← expect "(" identifier.rest
  arguments ← commaList expression open.rest
  close ← expect ")" arguments.rest
  pure
    { value: Call
        { start: identifier.value.span.start, end: close.value.span.end }
        identifier.value.text
        arguments.value
    , rest: close.rest
    }
