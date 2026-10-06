module Format.Parse.Literal (integerLiteral, integerStart) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Int as Int
import Data.Maybe (maybe')
import Data.String.CodeUnits as String
import Domain.Syntax (ErrorCode(..), Span, problem)
import Format.Parse.Core (Parser, failAt, peek, take)

-- Expressions and patterns share one integer syntax: an optional minus
-- token, then digits, range-checked to signed 32 bits.
integerLiteral ∷ Parser { value ∷ Int, span ∷ Span }
integerLiteral state =
  if peek state == "-" then negativeInteger state
  else unsignedInteger state

integerStart ∷ String → Boolean
integerStart text = text == "-" || decimalToken text

negativeInteger ∷ Parser { value ∷ Int, span ∷ Span }
negativeInteger state = do
  minus ← take state
  digits ← take minus.rest
  if decimalToken digits.value.text then
    integer ("-" <> digits.value.text)
      { start: minus.value.span.start, end: digits.value.span.end }
      digits.rest
  else failAt minus.rest "Expected digits after minus"

unsignedInteger ∷ Parser { value ∷ Int, span ∷ Span }
unsignedInteger state = do
  token ← take state
  if decimalToken token.value.text then
    integer token.value.text token.value.span token.rest
  else failAt state "Expected an integer"

-- Consumes nothing: it range-checks already-taken text, then continues.
integer ∷ String → Span → Parser { value ∷ Int, span ∷ Span }
integer text span rest = maybe' outOfRange parsedInteger
  (Int.fromString text)
  where
  outOfRange _ = Left
    (problem IntegerRange span "Integer literal is outside signed 32-bit range")
  parsedInteger value = Right { value: { value, span }, rest }

decimalToken ∷ String → Boolean
decimalToken text = Array.all isDigit (String.toCharArray text)
  where
  isDigit character = character >= '0' && character <= '9'
