module Sprig.Parse.Pattern (pattern, arms) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Sprig.Lex (isName)
import Sprig.Model
  ( Arm
  , Diagnostic
  , Expr
  , Pattern(..)
  , Span
  , Token
  , exprSpan
  , isUpper
  , patternSpan
  )
import Sprig.Parse.Core
  ( Parsed
  , Parser
  , expect
  , failAt
  , nonEmptyList
  , peek
  , take
  , upperName
  )
import Sprig.Parse.Literal (integerLiteral, integerStart)

-- An upper name is always a constructor and a lower name always a binder,
-- so a misspelled constructor never becomes a catch-all.
pattern ∷ Parser Pattern
pattern state = case peek state of
  "_" → simple PWildcard state
  "true" → simple (flip PBool true) state
  "false" → simple (flip PBool false) state
  text
    | integerStart text → intPattern state
    | isName text && isUpper text → ctorPattern state
    | isName text → simple (binder text) state
    | otherwise → failAt state "Expected a pattern"
  where
  binder text span = PBind span text

-- One or more arms and an optional trailing comma. The closing `}` is left
-- for the caller, whose match span ends there.
arms ∷ Parser Expr → Parser (Array Arm)
arms body state = do
  first ← arm body state
  remaining ← armTail body first.rest
  pure { value: Array.cons first.value remaining.value, rest: remaining.rest }

simple ∷ (Span → Pattern) → Parser Pattern
simple build state = do
  token ← take state
  pure { value: build token.value.span, rest: token.rest }

intPattern ∷ Parser Pattern
intPattern state = do
  literal ← integerLiteral state
  pure
    { value: PInt literal.value.span literal.value.value
    , rest: literal.rest
    }

ctorPattern ∷ Parser Pattern
ctorPattern state = do
  identifier ← upperName state
  if peek identifier.rest == "(" then ctorFields identifier
  else pure (bareCtor identifier)

bareCtor ∷ Parsed Token → Parsed Pattern
bareCtor identifier =
  { value: PCtor identifier.value.span identifier.value.text []
  , rest: identifier.rest
  }

ctorFields ∷ Parsed Token → Either Diagnostic (Parsed Pattern)
ctorFields identifier = do
  open ← expect "(" identifier.rest
  fields ← nonEmptyList pattern open.rest
  close ← expect ")" fields.rest
  pure
    { value: PCtor
        { start: identifier.value.span.start, end: close.value.span.end }
        identifier.value.text
        fields.value
    , rest: close.rest
    }

arm ∷ Parser Expr → Parser Arm
arm body state = do
  matched ← pattern state
  arrow ← expect "=>" matched.rest
  result ← body arrow.rest
  pure
    { value:
        { pattern: matched.value
        , body: result.value
        , span:
            { start: (patternSpan matched.value).start
            , end: (exprSpan result.value).end
            }
        }
    , rest: result.rest
    }

armTail ∷ Parser Expr → Parser (Array Arm)
armTail body state =
  if peek state /= "," then Right { value: [], rest: state }
  else afterComma body state

afterComma ∷ Parser Expr → Parser (Array Arm)
afterComma body state = do
  comma ← expect "," state
  if peek comma.rest == "}" then Right { value: [], rest: comma.rest }
  else arms body comma.rest
