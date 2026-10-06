module Format.Parse (parse) where

import Prelude
import Data.Array as Array
import Data.Either (Either)
import Format.Lex (lex, endPosition)
import Domain.Syntax (Diagnostic, FunctionDecl, Parameter, Program)
import Format.Parse.Core (Parser, State, commaList, expect, name, peek, typeRef)
import Format.Parse.Declaration (typeDeclaration)
import Format.Parse.Expression (expression)

parse ∷ String → Either Diagnostic Program
parse source = do
  tokens ← lex source
  declarations { tokens, eof: endPosition source }

declarations ∷ State → Either Diagnostic Program
declarations state
  | peek state == "<end>" = pure { types: [], functions: [] }
  | peek state == "type" = nextType state
  | otherwise = nextFunction state

nextType ∷ State → Either Diagnostic Program
nextType state = do
  first ← typeDeclaration state
  rest ← declarations first.rest
  pure rest { types = Array.cons first.value rest.types }

nextFunction ∷ State → Either Diagnostic Program
nextFunction state = do
  first ← function state
  rest ← declarations first.rest
  pure rest { functions = Array.cons first.value rest.functions }

function ∷ Parser FunctionDecl
function state = do
  keyword ← expect "fn" state
  identifier ← name keyword.rest
  open ← expect "(" identifier.rest
  parameters ← commaList parameter open.rest
  close ← expect ")" parameters.rest
  colon ← expect ":" close.rest
  result ← typeRef colon.rest
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
  ty ← typeRef colon.rest
  pure
    { value:
        { name: identifier.value.text
        , ty: ty.value
        , span: identifier.value.span
        }
    , rest: ty.rest
    }
