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

-- Membership is a `case`, which compiles to a chain of comparisons: the
-- lexer asks it of each punctuation character and the parser asks
-- `reserved` of each name it dispatches on, and Array.elem's closures were
-- a measurable share of parsing (T003).
punctuation ∷ Char → Boolean
punctuation = case _ of
  '(' → true
  ')' → true
  ':' → true
  ',' → true
  '=' → true
  ';' → true
  '+' → true
  '-' → true
  '|' → true
  '{' → true
  '}' → true
  '<' → true
  '>' → true
  _ → false

reserved ∷ String → Boolean
reserved = case _ of
  "fn" → true
  "if" → true
  "then" → true
  "else" → true
  "true" → true
  "false" → true
  "Int" → true
  "Bool" → true
  "type" → true
  "match" → true
  "_" → true
  _ → false

-- The first characters of `twoCharacterTokens`.
pairStart ∷ Char → Boolean
pairStart = case _ of
  '=' → true
  '!' → true
  '<' → true
  '>' → true
  '-' → true
  '|' → true
  _ → false

lex ∷ String → Either Diagnostic (Array Token)
lex source = tailRecM (scan source) start
  where
  start = { index: 0, position: origin, tokens: Stack.empty }

-- The parser asks this of most tokens it dispatches on, so the text is
-- read in place rather than copied into a character array (T003).
isName ∷ String → Boolean
isName text = maybe false validName (String.charAt 0 text)
  where
  validName head = isLetter head
    && wordEnd text isNameChar 1 == String.length text
    && not (reserved text)

endPosition ∷ String → Position
endPosition = Array.foldl advance origin <<< String.toCharArray

-- One run of whitespace or one token per step. tailRecM runs the steps as
-- a loop, and indexing replaces Array.uncons, which copied the remaining
-- input per character (BACKLOG E002). The source is read in place, by
-- code unit: a token's text is a slice of it, not a rebuilt character
-- array (T003).
scan ∷ String → Scan → Scanned
scan source state = maybe' finished (scanAt source state)
  (String.charAt state.index source)
  where
  finished _ = Right (Done (Array.fromFoldable state.tokens))

scanAt ∷ String → Scan → Char → Scanned
scanAt source state head
  | isSpace head = continue (spaces source state)
  | isLetter head = continue (word source state isNameChar)
  | isDigit head = continue (word source state isDigit)
  | pairStart head, Just text ← twoCharacter source state.index =
      continue (emit text state)
  | punctuation head = continue (emit (String.singleton head) state)
  | otherwise = unexpected state.position head

continue ∷ Scan → Scanned
continue state = Right (Loop state)

-- A whole run of whitespace is one step (T003): a step per character was
-- most of lexing an indented source.
spaces ∷ String → Scan → Scan
spaces source state = state
  { index = skipped.index, position = skipped.position }
  where
  skipped = spaceEnd source state.index state.position

-- A self tail call, which purs compiles to a loop.
spaceEnd
  ∷ String → Int → Position → { index ∷ Int, position ∷ Position }
spaceEnd source index position =
  if maybe false isSpace (String.charAt index source) then
    spaceEnd source (index + 1)
      (maybe position (advance position) (String.charAt index source))
  else { index, position }

-- Two-character tokens win over their one-character prefixes: `->` over
-- the minus of a negative literal, `|>` over `|`. The pair is built once
-- and looked up, rather than each token's characters being compared with a
-- fresh slice of the input (T003).
twoCharacter ∷ String → Int → Maybe String
twoCharacter source index = Array.find (eq pair) twoCharacterTokens
  where
  pair = String.slice index (index + 2) source

twoCharacterTokens ∷ Array String
twoCharacterTokens = [ "=>", "==", "!=", "<=", ">=", "->", "|>" ]

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

word ∷ String → Scan → (Char → Boolean) → Scan
word source state predicate = emit text state
  where
  end = wordEnd source predicate state.index
  text = String.slice state.index end source

-- A self tail call, which purs compiles to a loop.
wordEnd ∷ String → (Char → Boolean) → Int → Int
wordEnd source predicate index =
  if maybe false predicate (String.charAt index source) then
    wordEnd source predicate (index + 1)
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
isSpace character = character == ' ' || character == '\n'
  || character == '\r'
  || character == '\t'

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
