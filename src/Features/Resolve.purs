module Features.Resolve (resolve) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Problem (EntryKind(..), Problem(..))
import Domain.Syntax as Syntax
import Features.Resolve.Expression (expression)
import Features.Resolve.Fresh (runFresh)
import Features.Resolve.Types (resolveType, typeTable)
import Domain.Resolved (Global)
import Domain.Resolved as Resolved

type Signature =
  { parameters ∷ Array Resolved.Parameter, result ∷ Resolved.Ty }

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
  bodies ← traverse (resolveFunction (globals tables.ctors) tables.ctors)
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
  { name: function.name, ref: Resolved.FunctionRef (Resolved.FunctionId index) }

ctorGlobal ∷ Int → Resolved.CtorInfo → Global
ctorGlobal index info =
  { name: info.name, ref: Resolved.CtorRef (Resolved.CtorId index) }

resolveSignature
  ∷ Array Resolved.TypeInfo
  → Syntax.FunctionDecl
  → Either Syntax.Diagnostic Signature
resolveSignature types function = do
  parameters ← traverse resolveParameter function.parameters
  result ← resolveType types function.result
  pure { parameters, result }
  where
  resolveParameter parameter = withType parameter
    <$> resolveType types parameter.ty
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
checkEntry definition =
  if not (Array.null definition.function.parameters) then invalid
    EntryParameters
  else pure (Resolved.FunctionId definition.index)
  where
  invalid kind = Left
    (Syntax.problemAt (EntryProblem kind) definition.function.span)

resolveFunction
  ∷ Array Global
  → Array Resolved.CtorInfo
  → Definition
  → Either Syntax.Diagnostic Resolved.FunctionDecl
resolveFunction globals ctors definition = withBody <$> runFresh
  (Array.length locals)
  (expression scope definition.function.body)
  where
  scope = { globals, ctors, locals }
  locals = Array.mapWithIndex parameterLocal definition.signature.parameters
  parameterLocal index parameter =
    { name: parameter.name, id: Resolved.LocalId index }
  withBody body =
    { id: Resolved.FunctionId definition.index
    , parameters: definition.signature.parameters
    , result: definition.signature.result
    , body
    , span: definition.function.span
    }
