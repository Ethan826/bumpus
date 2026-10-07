module Format.Lex (Token, lex, isName, isUpper, endPosition) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.String.CodeUnits as String
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Position, Span, origin, problemAt)
import Format.Stack (Stack)
import Format.Stack as Stack

type Token = { text ∷ String, span ∷ Span }
type Scan = { index ∷ Int, position ∷ Position, tokens ∷ Stack Token }
type Scanned = Either Diagnostic (Step Scan (Array Token))

punctuation ∷ Array Char
punctuation =
  [ '(', ')', ':', ',', '=', ';', '+', '-', '|', '{', '}', '<', '>' ]

reserved ∷ Array String
reserved =
  [ "fn"
  , "if"
  , "then"
  , "else"
  , "true"
  , "false"
  , "Int"
  , "Bool"
  , "type"
  , "match"
  , "_"
  ]

lex ∷ String → Either Diagnostic (Array Token)
lex source = tailRecM (scan (String.toCharArray source)) start
  where
  start = { index: 0, position: origin, tokens: Stack.empty }

isName ∷ String → Boolean
isName text = maybe false validName (Array.uncons (String.toCharArray text))
  where
  validName { head, tail } = isLetter head && Array.all isNameChar tail && not
    (Array.elem text reserved)

endPosition ∷ String → Position
endPosition = Array.foldl advance origin <<< String.toCharArray

-- One whitespace character or one token per step. tailRecM runs the steps as
-- a loop, and indexing replaces Array.uncons, which copied the remaining
-- input per character (BACKLOG E002).
scan ∷ Array Char → Scan → Scanned
scan characters state = maybe' finished (scanAt characters state)
  (Array.index characters state.index)
  where
  finished _ = Right (Done (Array.fromFoldable state.tokens))

scanAt ∷ Array Char → Scan → Char → Scanned
scanAt characters state head
  | isSpace head = continue (skip state head)
  | isLetter head = continue (word characters state isNameChar)
  | isDigit head = continue (word characters state isDigit)
  | Just text ← twoCharacter characters state.index = continue (emit text state)
  | Array.elem head punctuation = continue (emit (String.singleton head) state)
  | otherwise = unexpected state.position head

continue ∷ Scan → Scanned
continue state = Right (Loop state)

skip ∷ Scan → Char → Scan
skip state character = state
  { index = state.index + 1, position = advance state.position character }

-- Two-character tokens win over their one-character prefixes.
twoCharacter ∷ Array Char → Int → Maybe String
twoCharacter characters index = Array.find matches twoCharacterTokens
  where
  matches text = String.toCharArray text == Array.slice index (index + 2)
    characters

twoCharacterTokens ∷ Array String
twoCharacterTokens = [ "=>", "==", "!=", "<=", ">=" ]

-- Tokens never contain a newline, so a token only moves the column.
emit ∷ String → Scan → Scan
emit text state = state
  { index = state.index + width
  , position = next
  , tokens = Stack.push token state.tokens
  }
  where
  width = String.length text
  next = state.position
    { offset = state.position.offset + width
    , column = state.position.column + width
    }
  token = { text, span: { start: state.position, end: next } }

unexpected ∷ Position → Char → Scanned
unexpected position character = Left (problemAt Lexical span)
  where
  span = { start: position, end: advance position character }

word ∷ Array Char → Scan → (Char → Boolean) → Scan
word characters state predicate = emit text state
  where
  end = wordEnd characters predicate state.index
  text = String.fromCharArray (Array.slice state.index end characters)

-- A self tail call, which purs compiles to a loop.
wordEnd ∷ Array Char → (Char → Boolean) → Int → Int
wordEnd characters predicate index =
  if maybe false predicate (Array.index characters index) then
    wordEnd characters predicate (index + 1)
  else index

advance ∷ Position → Char → Position
advance position character =
  if character == '\n' then
    nextLine
  else nextColumn
  where
  nextLine = { offset: position.offset + 1, line: position.line + 1, column: 1 }
  nextColumn = position
    { offset = position.offset + 1, column = position.column + 1 }

isSpace ∷ Char → Boolean
isSpace character = Array.elem character [ ' ', '\n', '\r', '\t' ]

isLetter ∷ Char → Boolean
isLetter character = character >= 'a' && character <= 'z'
  || character >= 'A' && character <= 'Z'
  || character == '_'

isDigit ∷ Char → Boolean
isDigit character = character >= '0' && character <= '9'

isNameChar ∷ Char → Boolean
isNameChar character = isLetter character || isDigit character

isUpper ∷ String → Boolean
isUpper text = maybe false upper (String.charAt 0 text)
  where
  upper character = character >= 'A' && character <= 'Z'
