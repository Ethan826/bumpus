module Sprig.Parse.Expression (expression) where

import Prelude
import Data.Either (Either(..))
import Data.Int as Int
import Data.Array as Array
import Data.String.CodeUnits as String
import Sprig.Lex as Lex
import Sprig.Model as Model
import Sprig.Parse.Core as Core
import Data.Maybe (maybe)
import Sprig.Model (ErrorCode(..), Expr(..), exprSpan, problem)
import Sprig.Parse.Core (Parser, commaList, expect, failAt, name, peek, take)

expression ∷ Parser Expr
expression state =
  if peek state == "if" then conditional state
  else additive state

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
  let
    span =
      { start: (exprSpan first.value).start
      , end: (exprSpan second.value).end
      }
  addition { value: Add span first.value second.value, rest: second.rest }

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

atom ∷ Parser Expr
atom state = case peek state of
  "(" → parenthesized state
  "true" → boolean true state
  "false" → boolean false state
  "-" → negativeInteger state
  _ → namedOrInvalid state

parenthesized ∷ Parser Expr
parenthesized state = do
  open ← expect "(" state
  inside ← expression open.rest
  close ← expect ")" inside.rest
  pure { value: inside.value, rest: close.rest }

negativeInteger ∷ Parser Expr
negativeInteger state = do
  minus ← take state
  digits ← take minus.rest
  if decimalToken digits.value.text then
    integer ("-" <> digits.value.text)
      { start: minus.value.span.start, end: digits.value.span.end }
      digits.rest
  else failAt minus.rest "Expected digits after minus"

integer
  ∷ String
  → Model.Span
  → Core.State
  → Either Model.Diagnostic (Core.Parsed Expr)
integer text span rest = maybe outOfRange parsedInteger (Int.fromString text)
  where
  outOfRange = Left
    (problem IntegerRange span "Integer literal is outside signed 32-bit range")
  parsedInteger value = Right { value: Integer span value, rest }

boolean ∷ Boolean → Parser Expr
boolean value state = do
  token ← take state
  pure { value: Boolean token.value.span value, rest: token.rest }

namedOrInvalid ∷ Parser Expr
namedOrInvalid state = do
  token ← take state
  if decimalToken token.value.text then
    integer token.value.text token.value.span token.rest
  else if Lex.isName token.value.text then named state
  else failAt state "Expected an expression"

decimalToken ∷ String → Boolean
decimalToken text = Array.all isDigit (String.toCharArray text)
  where
  isDigit character = character >= '0' && character <= '9'

named ∷ Parser Expr
named state = do
  identifier ← name state
  if peek identifier.rest /= "(" then
    pure
      { value: Variable identifier.value.span identifier.value.text
      , rest: identifier.rest
      }
  else namedCall identifier

namedCall ∷ Core.Parsed Model.Token → Either Model.Diagnostic (Core.Parsed Expr)
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
