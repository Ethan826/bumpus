module Format.Parse.Declaration (typeDeclaration, typeRef) where

import Prelude
import Data.Either (Either(..))
import Data.Maybe (Maybe, fromMaybe)
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( CtorDecl
  , Diagnostic
  , Span
  , TypeDecl
  , TypeRef(..)
  , problemAt
  )
import Format.Lex (Token, isName, isUpper)
import Format.Parse.Grammar
  ( Parser
  , expect
  , optionalOn
  , refine
  , sepBy1
  , spanned
  , token
  , upperName
  )

typeDeclaration ∷ Parser TypeDecl
typeDeclaration = typeOf <$> expect "type" <*> upperName <* expect "="
  <*> sepBy1 "|" constructor
  <*> expect ";"
  where
  typeOf keyword identifier ctors semicolon =
    { name: identifier.text
    , ctors
    , span: { start: keyword.span.start, end: semicolon.span.end }
    }

-- Int, Bool or a capitalized name; otherwise E_SYNTAX at that token.
typeRef ∷ Parser TypeRef
typeRef = refine known token

known ∷ Token → Either Diagnostic TypeRef
known found
  | found.text == "Int" = Right (IntRef found.span)
  | found.text == "Bool" = Right (BoolRef found.span)
  | isName found.text && isUpper found.text =
      Right (NamedRef found.span found.text)
  | otherwise = Left (problemAt (Syntax "Expected a type") found.span)

-- Spans the name alone, or through the `)` closing its fields. A payload
-- constructor needs at least one field; `A()` is rejected at `)`.
constructor ∷ Parser CtorDecl
constructor = spanned ctorOf (parts <$> upperName <*> optionalOn "(" fields)
  where
  parts identifier found = { identifier, fields: found }
  fields = expect "(" *> sepBy1 "," typeRef <* expect ")"

ctorOf
  ∷ Span → { identifier ∷ Token, fields ∷ Maybe (Array TypeRef) } → CtorDecl
ctorOf span found =
  { name: found.identifier.text, fields: fromMaybe [] found.fields, span }
