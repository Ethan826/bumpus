module Format.Parse.Literal (integerLiteral, integerStart) where

import Prelude
import Data.Either (Either(..))
import Data.Int as Int
import Data.Maybe (maybe')
import Data.String.CodeUnits as String
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Format.Lex (Token)
import Format.Parse.Grammar
  ( Parser
  , dispatch
  , expect
  , on
  , refine
  , spanned
  , token
  )

-- Expressions and patterns share one integer syntax: an optional minus
-- token, then digits, range-checked to signed 32 bits.
integerLiteral ∷ Parser { value ∷ Int, span ∷ Span }
integerLiteral = refine inRange
  (dispatch [ on "-" negativeDigits ] (digitsOr "Expected an integer"))

integerStart ∷ String → Boolean
integerStart text = text == "-" || decimalToken text

-- The minus and its digits as one token-like span and text.
negativeDigits ∷ Parser Token
negativeDigits = spanned negated
  (expect "-" *> digitsOr "Expected digits after minus")
  where
  negated span digits = { text: "-" <> digits.text, span }

-- The next token, which must be digits; otherwise E_SYNTAX at that token.
digitsOr ∷ String → Parser Token
digitsOr message = refine digitsOnly token
  where
  digitsOnly found =
    if decimalToken found.text then Right found
    else Left (problemAt (Syntax message) found.span)

inRange ∷ Token → Either Diagnostic { value ∷ Int, span ∷ Span }
inRange digits = maybe' outOfRange parsedInteger (Int.fromString digits.text)
  where
  outOfRange _ = Left (problemAt IntegerOutOfRange digits.span)
  parsedInteger value = Right { value, span: digits.span }

-- Counted in place: the primary dispatch asks this of every name token,
-- and copying each into a character array was a measurable share of
-- parsing (T003).
decimalToken ∷ String → Boolean
decimalToken text = String.countPrefix isDigit text == String.length text
  where
  isDigit character = character >= '0' && character <= '9'
