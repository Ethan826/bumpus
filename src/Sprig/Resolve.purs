module Sprig.Resolve (resolve) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_, for_)
import Data.Maybe (maybe)
import Data.Traversable (traverse)
import Sprig.Model as Syntax
import Sprig.Resolved as R

type Global = { name ∷ String, id ∷ R.FunctionId }

resolve ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic R.Program
resolve functions = do
  unique functions
  let globals = Array.mapWithIndex globalBinding functions
  entry ← maybe missingEntry (entryPoint globals) (Array.find isEntry functions)
  resolved ← traverse (resolveFunction globals)
    (Array.mapWithIndex indexedFunction functions)
  pure { functions: resolved, entry }
  where
  globalBinding index function = { name: function.name, id: R.FunctionId index }
  indexedFunction index function = { index, function }
  isEntry function = function.name == "main"

missingEntry ∷ Either Syntax.Diagnostic R.FunctionId
missingEntry = Left
  ( Syntax.problem Syntax.EntryError
      { start: Syntax.origin, end: Syntax.origin }
      "Expected fn main(): Int or Bool"
  )

entryPoint
  ∷ Array Global → Syntax.FunctionDecl → Either Syntax.Diagnostic R.FunctionId
entryPoint globals function =
  if Array.null function.parameters then lookupGlobal globals function.span
    "main"
  else Left
    ( Syntax.problem Syntax.EntryError function.span
        "main must have no parameters"
    )

unique ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic Unit
unique functions = for_ functions uniqueFunction
  where
  uniqueFunction function = do
    when (Array.length (Array.filter (sameName function) functions) > 1)
      ( Left
          ( Syntax.problem Syntax.DuplicateName function.span
              ("Duplicate function " <> function.name)
          )
      )
    traverse_ (uniqueParameter function.parameters) function.parameters
  sameName function other = other.name == function.name

uniqueParameter
  ∷ Array Syntax.Parameter → Syntax.Parameter → Either Syntax.Diagnostic Unit
uniqueParameter parameters parameter =
  when (Array.length (Array.filter sameName parameters) > 1)
    ( Left
        ( Syntax.problem Syntax.DuplicateName parameter.span
            ("Duplicate parameter " <> parameter.name)
        )
    )
  where
  sameName other = other.name == parameter.name

resolveFunction
  ∷ Array Global
  → { index ∷ Int, function ∷ Syntax.FunctionDecl }
  → Either Syntax.Diagnostic R.FunctionDecl
resolveFunction globals { index, function } = do
  body ← expression globals function.parameters function.body
  pure
    { id: R.FunctionId index
    , parameters: function.parameters
    , result: function.result
    , body
    , span: function.span
    }

lookupGlobal
  ∷ Array Global → Syntax.Span → String → Either Syntax.Diagnostic R.FunctionId
lookupGlobal globals span name = maybe missing found
  (Array.find namedGlobal globals)
  where
  missing = Left
    (Syntax.problem Syntax.UnboundName span ("Unbound function " <> name))
  found global = Right global.id
  namedGlobal global = global.name == name

expression
  ∷ Array Global
  → Array Syntax.Parameter
  → Syntax.Expr
  → Either Syntax.Diagnostic R.Expr
expression globals parameters = case _ of
  Syntax.Integer span value → pure (R.Integer span value)
  Syntax.Boolean span value → pure (R.Boolean span value)
  Syntax.Variable span name → localReference parameters span name
  Syntax.Call span name arguments → callReference globals parameters span name
    arguments
  Syntax.Add span left right → R.Add span <$> expression globals parameters left
    <*> expression globals parameters right
  Syntax.If span condition yes no → R.If span
    <$> expression globals parameters condition
    <*> expression globals parameters yes
    <*> expression globals parameters no

localReference
  ∷ Array Syntax.Parameter
  → Syntax.Span
  → String
  → Either Syntax.Diagnostic R.Expr
localReference parameters span name = maybe missing found
  (Array.findIndex namedParameter parameters)
  where
  missing = Left
    (Syntax.problem Syntax.UnboundName span ("Unbound local " <> name))
  found index = pure (R.Local span (R.LocalId index))
  namedParameter parameter = parameter.name == name

callReference
  ∷ Array Global
  → Array Syntax.Parameter
  → Syntax.Span
  → String
  → Array Syntax.Expr
  → Either Syntax.Diagnostic R.Expr
callReference globals parameters span name arguments = do
  when (Array.any namedParameter parameters)
    ( Left
        ( Syntax.problem Syntax.NotCallable span
            ("Local is not callable: " <> name)
        )
    )
  id ← lookupGlobal globals span name
  resolved ← traverse (expression globals parameters) arguments
  pure (R.Call span id resolved)
  where
  namedParameter parameter = parameter.name == name
