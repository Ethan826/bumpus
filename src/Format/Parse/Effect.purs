module Format.Parse.Effect (effectDeclaration) where

import Prelude
import Data.Maybe (fromMaybe)
import Domain.Syntax
  ( EffectDecl
  , OperationDecl
  , Parameter
  , Sort(..)
  , TypeParameter
  )
import Format.Parse.Grammar
  ( Parser
  , commaList
  , expect
  , manyOn
  , name
  , optionalOn
  , sepBy1
  , upperName
  )
import Format.Parse.Type (typeAndRow, typeRef)

effectDeclaration ∷ Parser EffectDecl
effectDeclaration = effectOf <$> expect "effect" <*> upperName
  <*> optionalOn "(" parameters
  <* expect "{"
  <*> manyOn "fn" operation
  <* expect "}"
  <*> expect ";"
  where
  parameters = expect "(" *> sepBy1 "," typeParameter <* expect ")"
  effectOf keyword identifier found operations semicolon =
    { name: identifier.text
    , parameters: fromMaybe [] found
    , operations
    , span: { start: keyword.span.start, end: semicolon.span.end }
    }

operation ∷ Parser OperationDecl
operation = operationOf <$> expect "fn" <*> name <* expect "("
  <*> commaList parameter
  <* expect ")"
  <* expect ":"
  <*> typeAndRow
  <*> expect ";"
  where
  operationOf keyword identifier parameters result semicolon =
    { name: identifier.text
    , parameters
    , result: result.ty
    , row: result.row
    , span: { start: keyword.span.start, end: semicolon.span.end }
    }

parameter ∷ Parser Parameter
parameter = parameterOf <$> name <* expect ":" <*> typeRef
  where
  parameterOf identifier ty =
    { name: identifier.text, ty, span: identifier.span }

typeParameter ∷ Parser TypeParameter
typeParameter = parameterOf <$> name
  where
  parameterOf identifier =
    { name: identifier.text, sort: TypeSort, span: identifier.span }
