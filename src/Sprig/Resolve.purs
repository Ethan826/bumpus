module Sprig.Resolve (resolve) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_, for_)
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Sprig.Model as Syntax
import Sprig.Resolved as Resolved

type Global = { name ∷ String, id ∷ Resolved.FunctionId }

missingEntry ∷ Either Syntax.Diagnostic Resolved.FunctionId
missingEntry = Left
  ( Syntax.problem Syntax.EntryError
      { start: Syntax.origin, end: Syntax.origin }
      "Expected fn main(): Int or Bool"
  )

resolve ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic Resolved.Program
resolve functions = do
  unique functions
  entry ← maybe' absentEntry resolveEntry (Array.find isEntry functions)
  resolved ← traverse resolveDefinition
    (Array.mapWithIndex indexedFunction functions)
  pure { functions: resolved, entry }
  where
  globals = Array.mapWithIndex globalBinding functions
  absentEntry _ = missingEntry
  resolveEntry function = entryPoint globals function
  resolveDefinition definition = resolveFunction globals definition
  globalBinding index function =
    { name: function.name, id: Resolved.FunctionId index }
  indexedFunction index function = { index, function }
  isEntry function = function.name == "main"

entryPoint
  ∷ Array Global
  → Syntax.FunctionDecl
  → Either Syntax.Diagnostic Resolved.FunctionId
entryPoint globals function =
  if Array.null function.parameters then lookupGlobal globals function.span
    "main"
  else invalidEntry
  where
  invalidEntry = Left
    ( Syntax.problem Syntax.EntryError function.span
        "main must have no parameters"
    )

unique ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic Unit
unique functions = for_ functions uniqueFunction
  where
  uniqueFunction function = do
    when (Array.length (Array.filter namedFunction functions) > 1)
      ( Left
          ( Syntax.problem Syntax.DuplicateName function.span
              ("Duplicate function " <> function.name)
          )
      )
    traverse_ checkParameter function.parameters
    where
    checkParameter parameter = uniqueParameter function.parameters parameter
    namedFunction other = other.name == function.name

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
  → Either Syntax.Diagnostic Resolved.FunctionDecl
resolveFunction globals { index, function } = do
  body ← expression globals function.parameters function.body
  pure
    { id: Resolved.FunctionId index
    , parameters: function.parameters
    , result: function.result
    , body
    , span: function.span
    }

lookupGlobal
  ∷ Array Global
  → Syntax.Span
  → String
  → Either Syntax.Diagnostic Resolved.FunctionId
lookupGlobal globals span name = maybe' missing found
  (Array.find namedGlobal globals)
  where
  missing _ = Left
    (Syntax.problem Syntax.UnboundName span ("Unbound function " <> name))
  found global = Right global.id
  namedGlobal global = global.name == name

expression
  ∷ Array Global
  → Array Syntax.Parameter
  → Syntax.Expr
  → Either Syntax.Diagnostic Resolved.Expr
expression globals parameters = case _ of
  Syntax.Integer span value → pure (Resolved.Integer span value)
  Syntax.Boolean span value → pure (Resolved.Boolean span value)
  Syntax.Variable span name → localReference parameters span name
  Syntax.Call span name arguments → callReference globals parameters span name
    arguments
  Syntax.Add span left right → resolveAddition span left right
  Syntax.If span condition yes no → resolveConditional span condition yes no
  where
  resolveAddition span left right = Resolved.Add span
    <$> expression globals parameters left
    <*> expression globals parameters right
  resolveConditional span condition yes no = Resolved.If span
    <$> expression globals parameters condition
    <*> expression globals parameters yes
    <*> expression globals parameters no

localReference
  ∷ Array Syntax.Parameter
  → Syntax.Span
  → String
  → Either Syntax.Diagnostic Resolved.Expr
localReference parameters span name = maybe' missing found
  (Array.findIndex namedParameter parameters)
  where
  missing _ = Left
    (Syntax.problem Syntax.UnboundName span ("Unbound local " <> name))
  found index = pure (Resolved.Local span (Resolved.LocalId index))
  namedParameter parameter = parameter.name == name

callReference
  ∷ Array Global
  → Array Syntax.Parameter
  → Syntax.Span
  → String
  → Array Syntax.Expr
  → Either Syntax.Diagnostic Resolved.Expr
callReference globals parameters span name arguments = do
  when (Array.any namedParameter parameters)
    ( Left
        ( Syntax.problem Syntax.NotCallable span
            ("Local is not callable: " <> name)
        )
    )
  id ← lookupGlobal globals span name
  resolved ← traverse resolveArgument arguments
  pure (Resolved.Call span id resolved)
  where
  resolveArgument argument = expression globals parameters argument
  namedParameter parameter = parameter.name == name
