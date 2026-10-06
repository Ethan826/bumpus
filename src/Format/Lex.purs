module Format.Lex (Token, lex, isName, isUpper, endPosition) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.String.CodeUnits as String
import Domain.Syntax
  ( ErrorCode(..)
  , Diagnostic
  , Position
  , Span
  , origin
  , problem
  )

type Token = { text ∷ String, span ∷ Span }

punctuation ∷ Array Char
punctuation = [ '(', ')', ':', ',', '=', ';', '+', '-', '|', '{', '}' ]

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
lex source = scan origin (String.toCharArray source) []

isName ∷ String → Boolean
isName text = maybe false validName (Array.uncons (String.toCharArray text))
  where
  validName { head, tail } = isLetter head && Array.all isNameChar tail && not
    (Array.elem text reserved)

endPosition ∷ String → Position
endPosition = Array.foldl advance origin <<< String.toCharArray

scan ∷ Position → Array Char → Array Token → Either Diagnostic (Array Token)
scan position characters tokens = maybe' finished scanHead
  (Array.uncons characters)
  where
  finished _ = Right tokens
  scanHead { head, tail }
    | isSpace head = scan (advance position head) tail tokens
    | isLetter head = word position characters tokens isNameChar
    | isDigit head = word position characters tokens isDigit
    | head == '=' && Array.head tail == Just '>' = arrow position tail tokens
    | Array.elem head punctuation = scanPunctuation position head tail tokens
    | otherwise = unexpected position head

scanPunctuation
  ∷ Position → Char → Array Char → Array Token → Either Diagnostic (Array Token)
scanPunctuation position character tail tokens = scan next tail
  (Array.snoc tokens token)
  where
  next = advance position character
  token =
    { text: String.singleton character, span: { start: position, end: next } }

arrow ∷ Position → Array Char → Array Token → Either Diagnostic (Array Token)
arrow position tail tokens = scan next (Array.drop 1 tail)
  (Array.snoc tokens token)
  where
  next =
    { offset: position.offset + 2
    , line: position.line
    , column: position.column + 2
    }
  token = { text: "=>", span: { start: position, end: next } }

unexpected ∷ Position → Char → Either Diagnostic (Array Token)
unexpected position character = Left
  (problem LexError span "Unexpected character")
  where
  span = { start: position, end: advance position character }

word
  ∷ Position
  → Array Char
  → Array Token
  → (Char → Boolean)
  → Either Diagnostic (Array Token)
word position characters tokens predicate = scan next parts.rest
  (Array.snoc tokens token)
  where
  parts = Array.span predicate characters
  next = Array.foldl advance position parts.init
  token =
    { text: String.fromCharArray parts.init
    , span: { start: position, end: next }
    }

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
