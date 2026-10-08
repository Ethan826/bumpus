module Features.Resolve (resolve) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), isNothing, maybe, maybe')
import Data.Traversable (traverse)
import Domain.Problem (EntryKind(..), Problem(..))
import Domain.Type (ground)
import Domain.Syntax as Syntax
import Features.Resolve.Expression (expression)
import Features.Resolve.Fresh (runFresh)
import Features.Resolve.Types (resolveType, typeTable)
import Features.Resolve.Variables (signatureVariables)
import Domain.Resolved (Global)
import Domain.Resolved as Resolved

type Signature =
  { variables ∷ Array String
  , parameters ∷ Array Resolved.Parameter
  , result ∷ Resolved.Ty Resolved.VarId
  }

type Definition =
  { index ∷ Int, function ∷ Syntax.FunctionDecl, signature ∷ Signature }

resolve ∷ Syntax.Program → Either Syntax.Diagnostic Resolved.Program
resolve program = do
  tables ← typeTable program
  signatures ← traverse (resolveSignature tables.types) functions
  let
    definitions = Array.mapWithIndex indexed
      (Array.zipWith pair functions signatures)
  entry ← entryPoint definitions
  -- Applied once, so the globals are built once rather than per function.
  bodies ← traverse (resolveFunction (globals tables.ctors) tables)
    definitions
  pure { types: tables.types, ctors: tables.ctors, functions: bodies, entry }
  where
  functions = program.functions
  pair function signature = { function, signature }
  indexed index entry =
    { index, function: entry.function, signature: entry.signature }
  globals ctors = Array.mapWithIndex functionGlobal functions
    <> Array.mapWithIndex ctorGlobal ctors

functionGlobal ∷ Int → Syntax.FunctionDecl → Global
functionGlobal index function =
  { name: function.name
  , ref: Resolved.GlobalFunction (Resolved.FunctionId index)
      (Array.length function.parameters)
  }

ctorGlobal ∷ Int → Resolved.CtorInfo → Global
ctorGlobal index info =
  { name: info.name, ref: Resolved.GlobalCtor (Resolved.CtorId index) }

resolveSignature
  ∷ Array Resolved.TypeInfo
  → Syntax.FunctionDecl
  → Either Syntax.Diagnostic Signature
resolveSignature types function = do
  parameters ← traverse resolveParameter function.parameters
  result ← resolveType types variables function.result
  pure { variables, parameters, result }
  where
  variables = signatureVariables
    (Array.snoc (map parameterType function.parameters) function.result)
  parameterType parameter = parameter.ty
  resolveParameter parameter = withType parameter
    <$> resolveType types variables parameter.ty
  withType parameter ty = { name: parameter.name, ty, span: parameter.span }

entryPoint
  ∷ Array Definition → Either Syntax.Diagnostic Resolved.FunctionId
entryPoint definitions = maybe' absent checkEntry
  (Array.find isEntry definitions)
  where
  isEntry definition = definition.function.name == "main"
  absent _ = Left
    ( Syntax.problemAt (EntryProblem MissingEntry)
        { start: Syntax.origin, end: Syntax.origin }
    )

checkEntry ∷ Definition → Either Syntax.Diagnostic Resolved.FunctionId
checkEntry definition = maybe (pure (Resolved.FunctionId definition.index))
  invalid
  (entryProblem definition)
  where
  invalid kind = Left
    (Syntax.problemAt (EntryProblem kind) definition.function.span)

-- `main` takes no parameters and returns a ground type: there is no caller
-- to choose its type arguments.
entryProblem ∷ Definition → Maybe EntryKind
entryProblem definition
  | not (Array.null definition.function.parameters) = Just EntryParameters
  | isNothing (ground definition.signature.result) = Just EntryPolymorphic
  | otherwise = Nothing

resolveFunction
  ∷ Array Global
  → Resolved.Tables
  → Definition
  → Either Syntax.Diagnostic Resolved.FunctionDecl
resolveFunction globals tables definition = withBody <$> runFresh
  (Array.length locals)
  (expression scope definition.function.body)
  where
  scope =
    { globals
    , ctors: tables.ctors
    , locals
    , types: tables.types
    , variables: definition.signature.variables
    }
  locals = Array.mapWithIndex parameterLocal definition.signature.parameters
  parameterLocal index parameter =
    { name: parameter.name, id: Resolved.LocalId index }
  withBody body =
    { id: Resolved.FunctionId definition.index
    , name: definition.function.name
    , variables: definition.signature.variables
    , parameters: definition.signature.parameters
    , result: definition.signature.result
    , body
    , span: definition.function.span
    }
