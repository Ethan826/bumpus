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
  , TypeParameter
  , TypeRef(..)
  , problemAt
  )
import Format.Lex (Token, isName, isUpper)
import Format.Parse.Grammar
  ( Parser
  , defer
  , dispatch
  , expect
  , failWith
  , nested
  , on
  , onWhen
  , optionalOn
  , refine
  , sepBy1
  , spanned
  , token
  , upperName
  )

type Applied = { identifier ∷ Token, arguments ∷ Maybe (Array TypeRef) }

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

-- Int, Bool, a type variable, or a capitalized name with optional type
-- arguments, each one nesting level deeper (ADR 006); otherwise E_SYNTAX at
-- that token. `List()` is rejected at `)`; `Int(a)` and `a(Int)` at `(`,
-- by whatever follows the type.
typeRef ∷ Parser TypeRef
typeRef = dispatch
  [ on "Int" (IntRef <$> tokenSpan)
  , on "Bool" (BoolRef <$> tokenSpan)
  , onWhen upperText (spanned appliedOf (parts <$> upperName <*> arguments))
  , onWhen lowerText (variable <$> token)
  ]
  (refine unknown token)
  where
  parts identifier found = { identifier, arguments: found }
  arguments = optionalOn "(" (expect "(" *> sepBy1 "," argument <* expect ")")
  argument = nested (defer later)
  later _ = typeRef
  variable found = VarRef found.span found.text

typeParameter ∷ Parser TypeParameter
typeParameter = dispatch [ onWhen lowerText (parameterOf <$> token) ]
  (failWith "Expected a type parameter")
  where
  parameterOf found = { name: found.text, span: found.span }

appliedOf ∷ Span → Applied → TypeRef
appliedOf span found =
  NamedRef span found.identifier.text (fromMaybe [] found.arguments)

unknown ∷ Token → Either Diagnostic TypeRef
unknown found = Left (problemAt (Syntax "Expected a type") found.span)

tokenSpan ∷ Parser Span
tokenSpan = spanOf <$> token
  where
  spanOf found = found.span

upperText ∷ String → Boolean
upperText text = isName text && isUpper text

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
