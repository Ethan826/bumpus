module Sprig.Lex (lex, isName, endPosition) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe)
import Data.String.CodeUnits as String
import Sprig.Model (ErrorCode(..), Diagnostic, Position, Token, origin, problem)

punctuation ∷ Array Char
punctuation = [ '(', ')', ':', ',', '=', ';', '+', '-' ]

lex ∷ String → Either Diagnostic (Array Token)
lex source = scan origin (String.toCharArray source) []

isName ∷ String → Boolean
isName text = maybe false validName (Array.uncons (String.toCharArray text))
  where
  validName { head, tail } = isLetter head && Array.all isNameChar tail && not
    (Array.elem text reserved)
  reserved = [ "fn", "if", "then", "else", "true", "false", "Int", "Bool" ]

endPosition ∷ String → Position
endPosition = Array.foldl advance origin <<< String.toCharArray

scan ∷ Position → Array Char → Array Token → Either Diagnostic (Array Token)
scan position characters tokens = maybe (Right tokens) scanHead
  (Array.uncons characters)
  where
  scanHead { head, tail }
    | isSpace head = scan (advance position head) tail tokens
    | isLetter head = word position characters tokens isNameChar
    | isDigit head = word position characters tokens isDigit
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
    { offset: position.offset + 1, line: position.line + 1, column: 1 }
  else position { offset = position.offset + 1, column = position.column + 1 }

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

