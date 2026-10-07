module Format.Parse.Cursor
  ( State
  , Parsed
  , Run
  , advance
  , skip
  , current
  , peekText
  , nextSpan
  , failAt
  , legacyState
  , grammarState
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe, maybe, maybe')
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Position, Span, problemAt)
import Format.Lex (Token)
import Format.Parse.Core as Core

-- The token cursor beneath Format.Parse.Grammar: reading the next token and
-- moving past it. Grammar is the only importer.

-- `lastEnd` is the end of the last consumed token; `spanned` ends there.
type State =
  { tokens ∷ Array Token, index ∷ Int, eof ∷ Position, lastEnd ∷ Position }

type Parsed a = { value ∷ a, rest ∷ State }

-- One production run from a state; the newtype hides it behind Apply.
type Run a = State → Either Diagnostic (Parsed a)

advance ∷ State → Token → State
advance state consumed =
  state { index = state.index + 1, lastEnd = consumed.span.end }

skip ∷ State → State
skip state = maybe state (advance state) (current state)

peekText ∷ State → String
peekText state = maybe "<end>" tokenText (current state)
  where
  tokenText found = found.text

nextSpan ∷ State → Span
nextSpan state = maybe' endSpan tokenSpan (current state)
  where
  endSpan _ = { start: state.eof, end: state.eof }
  tokenSpan found = found.span

current ∷ State → Maybe Token
current state = Array.index state.tokens state.index

failAt ∷ ∀ a. State → String → Either Diagnostic a
failAt state message = Left (problemAt (Syntax message) (nextSpan state))

legacyState ∷ State → Core.State
legacyState state =
  { tokens: state.tokens, index: state.index, eof: state.eof }

-- Recovers `lastEnd` from the token before `index`, if there is one.
grammarState ∷ Position → Core.State → State
grammarState fallback state =
  { tokens: state.tokens
  , index: state.index
  , eof: state.eof
  , lastEnd: maybe fallback tokenEnd (Array.index state.tokens previous)
  }
  where
  previous = state.index - 1
  tokenEnd found = found.span.end
