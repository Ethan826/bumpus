module Format.Parse.Core
  ( State
  , Parsed
  , Parser
  , peek
  , take
  , expect
  , name
  , upperName
  , typeRef
  , failAt
  , commaList
  , nonEmptyList
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Format.Lex (Token, isName, isUpper)
import Domain.Syntax
  ( ErrorCode(..)
  , Diagnostic
  , Position
  , TypeRef(..)
  , problem
  )

type State = { tokens ∷ Array Token, eof ∷ Position }
type Parsed a = { value ∷ a, rest ∷ State }
type Parser a = State → Either Diagnostic (Parsed a)

peek ∷ State → String
peek state = maybe "<end>" tokenText (Array.head state.tokens)
  where
  tokenText token = token.text

take ∷ Parser Token
take state = maybe' missing present (Array.uncons state.tokens)
  where
  missing _ = failAt state "Expected a token"
  present { head, tail } = Right { value: head, rest: state { tokens = tail } }

expect ∷ String → Parser Token
expect text state =
  if peek state == text then take state
  else failAt state ("Expected '" <> text <> "'")

name ∷ Parser Token
name state =
  if isName (peek state) then take state
  else failAt state "Expected an identifier"

upperName ∷ Parser Token
upperName state =
  if isName text && isUpper text then take state
  else failAt state "Expected a capitalized name"
  where
  text = peek state

typeRef ∷ Parser TypeRef
typeRef state = do
  token ← take state
  case token.value.text of
    "Int" → parsedType (IntRef token.value.span) token.rest
    "Bool" → parsedType (BoolRef token.value.span) token.rest
    text
      | isName text && isUpper text →
          parsedType (NamedRef token.value.span text) token.rest
    _ → invalidType token.value.span
  where
  parsedType value rest = Right { value, rest }
  invalidType span = Left (problem SyntaxError span "Expected a type")

failAt ∷ ∀ a. State → String → Either Diagnostic a
failAt state message = Left (problem SyntaxError span message)
  where
  span = maybe' endSpan tokenSpan
    (Array.head state.tokens)
  endSpan _ = { start: state.eof, end: state.eof }
  tokenSpan token = token.span

commaList ∷ ∀ a. Parser a → Parser (Array a)
commaList item state =
  if peek state == ")" then emptyList state
  else nonEmptyList item state

emptyList ∷ ∀ a. Parser (Array a)
emptyList state = Right { value: [], rest: state }

nonEmptyList ∷ ∀ a. Parser a → Parser (Array a)
nonEmptyList item state = do
  first ← item state
  remaining ← commaTail item first.rest
  pure { value: Array.cons first.value remaining.value, rest: remaining.rest }

commaTail ∷ ∀ a. Parser a → Parser (Array a)
commaTail item state =
  if peek state /= "," then emptyList state
  else afterComma item state

afterComma ∷ ∀ a. Parser a → Parser (Array a)
afterComma item state = do
  comma ← expect "," state
  first ← item comma.rest
  remaining ← commaTail item first.rest
  pure { value: Array.cons first.value remaining.value, rest: remaining.rest }
