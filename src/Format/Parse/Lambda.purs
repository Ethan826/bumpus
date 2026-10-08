module Format.Parse.Lambda (lambda) where

import Prelude
import Data.Maybe (Maybe(..))
import Domain.Syntax (Expr(..), LambdaParam, TypeRef, exprSpan)
import Format.Lex (Token, isName, isUpper)
import Format.Parse.Grammar
  ( Parser
  , dispatch
  , expect
  , failWith
  , on
  , onWhen
  , optionalOn
  , sepBy1
  , token
  )
import Format.Parse.Type (typeRef)

type Named = { name ∷ Maybe String, token ∷ Token }

-- `fn(x, _: Int) => body` spans `fn` through its body. `fn` is reserved,
-- so at the start of an expression it can only begin a lambda; the body
-- extends as far right as possible (FN001 design §1).
lambda ∷ Parser Expr → Parser Expr
lambda body = lambdaOf <$> expect "fn" <* expect "("
  <*> sepBy1 "," parameter
  <* expect ")"
  <* expect "=>"
  <*> body
  where
  lambdaOf keyword parameters result = Lambda
    { start: keyword.span.start, end: (exprSpan result).end }
    parameters
    result

-- A lowercase name or `_`, with an optional annotation; spans the name.
parameter ∷ Parser LambdaParam
parameter = parameterOf <$> named <*> optionalOn ":" (expect ":" *> typeRef)

named ∷ Parser Named
named = dispatch
  [ on "_" (namedOf Nothing <$> token)
  , onWhen lowerText (bound <$> token)
  ]
  (failWith "Expected a parameter")
  where
  bound found = namedOf (Just found.text) found

namedOf ∷ Maybe String → Token → Named
namedOf name found = { name, token: found }

parameterOf ∷ Named → Maybe TypeRef → LambdaParam
parameterOf found ty = { name: found.name, ty, span: found.token.span }

lowerText ∷ String → Boolean
lowerText text = isName text && not (isUpper text)
