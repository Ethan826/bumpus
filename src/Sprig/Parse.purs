module Sprig.Parse (parse) where

import Prelude
import Data.Array as Array
import Data.Either (Either)
import Sprig.Lex (lex, endPosition)
import Sprig.Model (Diagnostic, FunctionDecl, Parameter)
import Sprig.Parse.Core (Parser, State, commaList, expect, name, peek, typeName)
import Sprig.Parse.Expression (expression)

parse ∷ String → Either Diagnostic (Array FunctionDecl)
parse source = do
  tokens ← lex source
  functions { tokens, eof: endPosition source }

functions ∷ State → Either Diagnostic (Array FunctionDecl)
functions state =
  if peek state == "<end>" then pure []
  else nextFunction state

nextFunction ∷ State → Either Diagnostic (Array FunctionDecl)
nextFunction state = do
  first ← function state
  rest ← functions first.rest
  pure (Array.cons first.value rest)

function ∷ Parser FunctionDecl
function state = do
  keyword ← expect "fn" state
  identifier ← name keyword.rest
  open ← expect "(" identifier.rest
  parameters ← commaList parameter open.rest
  close ← expect ")" parameters.rest
  colon ← expect ":" close.rest
  result ← typeName colon.rest
  equals ← expect "=" result.rest
  body ← expression equals.rest
  semicolon ← expect ";" body.rest
  pure
    { value:
        { name: identifier.value.text
        , parameters: parameters.value
        , result: result.value
        , body: body.value
        , span:
            { start: keyword.value.span.start, end: semicolon.value.span.end }
        }
    , rest: semicolon.rest
    }

parameter ∷ Parser Parameter
parameter state = do
  identifier ← name state
  colon ← expect ":" identifier.rest
  ty ← typeName colon.rest
  pure
    { value:
        { name: identifier.value.text
        , ty: ty.value
        , span: identifier.value.span
        }
    , rest: ty.rest
    }
