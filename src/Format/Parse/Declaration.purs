module Format.Parse.Declaration (typeDeclaration) where

import Prelude
import Data.Maybe (Maybe, fromMaybe)
import Domain.Syntax (CtorDecl, Span, TypeDecl, TypeParameter, TypeRef)
import Format.Lex (Token, isName, isUpper)
import Format.Parse.Grammar
  ( Parser
  , dispatch
  , expect
  , failWith
  , onWhen
  , optionalOn
  , sepBy1
  , spanned
  , token
  , upperName
  )
import Format.Parse.Type (typeRef)

typeDeclaration ∷ Parser TypeDecl
typeDeclaration = typeOf <$> expect "type" <*> upperName
  <*> optionalOn "(" parameters
  <* expect "="
  <*> sepBy1 "|" constructor
  <*> expect ";"
  where
  parameters = expect "(" *> sepBy1 "," typeParameter <* expect ")"
  typeOf keyword identifier found ctors semicolon =
    { name: identifier.text
    , parameters: fromMaybe [] found
    , ctors
    , span: { start: keyword.span.start, end: semicolon.span.end }
    }

typeParameter ∷ Parser TypeParameter
typeParameter = dispatch [ onWhen lowerText (parameterOf <$> token) ]
  (failWith "Expected a type parameter")
  where
  parameterOf found = { name: found.text, span: found.span }

lowerText ∷ String → Boolean
lowerText text = isName text && not (isUpper text)

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
