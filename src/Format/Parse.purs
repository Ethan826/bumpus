module Format.Parse (parse) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Format.Lex (lex, endPosition)
import Domain.Syntax
  ( Diagnostic
  , FunctionDecl
  , Parameter
  , Program
  , TypeDecl
  )
import Format.Parse.Core
  ( Parsed
  , Parser
  , State
  , commaList
  , expect
  , name
  , peek
  , typeRef
  )
import Format.Parse.Declaration (typeDeclaration)
import Format.Parse.Expression (expression)
import Format.Stack (Stack)
import Format.Stack as Stack

-- Declarations parsed so far; Stack keeps accumulation linear.
type Found =
  { rest ∷ State, types ∷ Stack TypeDecl, functions ∷ Stack FunctionDecl }

parse ∷ String → Either Diagnostic Program
parse source = do
  tokens ← lex source
  tailRecM declarations
    { rest: { tokens, index: 0, eof: endPosition source }
    , types: Stack.empty
    , functions: Stack.empty
    }

-- One declaration per step. tailRecM runs the steps as a loop, where direct
-- recursion overflowed the stack on long programs (BACKLOG E002).
declarations ∷ Found → Either Diagnostic (Step Found Program)
declarations found
  | peek found.rest == "<end>" = Right (Done (finished found))
  | peek found.rest == "type" = map (addType found) (typeDeclaration found.rest)
  | otherwise = map (addFunction found) (function found.rest)

finished ∷ Found → Program
finished found =
  { types: Array.fromFoldable found.types
  , functions: Array.fromFoldable found.functions
  }

addType ∷ Found → Parsed TypeDecl → Step Found Program
addType found parsed = Loop found
  { rest = parsed.rest, types = Stack.push parsed.value found.types }

addFunction ∷ Found → Parsed FunctionDecl → Step Found Program
addFunction found parsed = Loop found
  { rest = parsed.rest, functions = Stack.push parsed.value found.functions }

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
