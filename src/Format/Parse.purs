module Format.Parse (parse) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..), either)
import Domain.Syntax
  ( Diagnostic
  , FunctionDecl
  , Parameter
  , Position
  , Program
  , TypeDecl
  )
import Format.Lex (Token, endPosition, lex)
import Format.Parse.Declaration (typeDeclaration, typeRef)
import Format.Parse.Expression (expression)
import Format.Parse.Grammar
  ( Parser
  , State
  , commaList
  , dispatch
  , expect
  , initialState
  , name
  , on
  , run
  )
import Format.Stack (Stack)
import Format.Stack as Stack

-- Declarations parsed so far; Stack keeps accumulation linear.
type Found =
  { rest ∷ State, types ∷ Stack TypeDecl, functions ∷ Stack FunctionDecl }

parse ∷ String → Either Diagnostic Program
parse source = either Left (program (endPosition source)) (lex source)

program ∷ Position → Array Token → Either Diagnostic Program
program eof tokens = tailRecM declarations
  { rest: initialState tokens eof
  , types: Stack.empty
  , functions: Stack.empty
  }

-- One declaration per step. tailRecM runs the steps as a loop, where direct
-- recursion overflowed the stack on long programs (BACKLOG E002).
declarations ∷ Found → Either Diagnostic (Step Found Program)
declarations found = map resume (run declaration found.rest)
  where
  resume parsed = parsed.value (found { rest = parsed.rest })

-- What the next declaration adds to those found so far.
declaration ∷ Parser (Found → Step Found Program)
declaration = dispatch
  [ on "<end>" (pure finished), on "type" (addType <$> typeDeclaration) ]
  (addFunction <$> function)

finished ∷ Found → Step Found Program
finished found = Done
  { types: Array.fromFoldable found.types
  , functions: Array.fromFoldable found.functions
  }

addType ∷ TypeDecl → Found → Step Found Program
addType parsed found =
  Loop found { types = Stack.push parsed found.types }

addFunction ∷ FunctionDecl → Found → Step Found Program
addFunction parsed found =
  Loop found { functions = Stack.push parsed found.functions }

function ∷ Parser FunctionDecl
function = functionOf <$> expect "fn" <*> name <* expect "("
  <*> commaList parameter
  <* expect ")"
  <* expect ":"
  <*> typeRef
  <* expect "="
  <*> expression
  <*> expect ";"
  where
  functionOf keyword identifier parameters result body semicolon =
    { name: identifier.text
    , parameters
    , result
    , body
    , span: { start: keyword.span.start, end: semicolon.span.end }
    }

-- A parameter spans its name.
parameter ∷ Parser Parameter
parameter = parameterOf <$> name <* expect ":" <*> typeRef
  where
  parameterOf identifier ty =
    { name: identifier.text, ty, span: identifier.span }
