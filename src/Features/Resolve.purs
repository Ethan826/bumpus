module Features.Resolve (resolve) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Map as Map
import Data.Maybe (Maybe(..), isNothing, maybe, maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Domain.Problem (EntryKind(..), Problem(..))
import Domain.Type.Parts (groundErased)
import Domain.Syntax as Syntax
import Features.Resolve.Expression (expression)
import Features.Resolve.Fresh (runFresh)
import Features.Resolve.Types (resolveTypeWith, typeTable)
import Features.Resolve.Row (resolveRow)
import Features.Resolve.Effect as Effect
import Features.Resolve.Variables (sortedVariables)
import Domain.Resolved (Global)
import Domain.Type (TyRow)
import Domain.Resolved as Resolved

type Signature =
  { variables ∷ Array String
  , sorts ∷ Array Syntax.Sort
  , row ∷ TyRow Resolved.VarId
  , parameters ∷ Array Resolved.Parameter
  , result ∷ Resolved.Ty Resolved.VarId
  }

type Definition =
  { index ∷ Int, function ∷ Syntax.FunctionDecl, signature ∷ Signature }

resolve ∷ Syntax.Program → Either Syntax.Diagnostic Resolved.Program
resolve program = do
  tables ← typeTable program
  effects ← Effect.effects tables.types program.effects
  signatures ← traverse
    (resolveSignature tables.types (Effect.summaries program.effects))
    functions
  let
    definitions = Array.mapWithIndex indexed
      (Array.zipWith pair functions signatures)
  entry ← entryPoint definitions
  -- Applied once, so the globals are built once rather than per function.
  bodies ← traverse
    ( resolveFunction
        ( globals tables.ctors <> Effect.globals effects
            <>
              [ { name: "print", ref: Resolved.BuiltinPrint }
              , { name: "crash", ref: Resolved.BuiltinCrash }
              ]
        )
        tables
        (Effect.summaries program.effects)
        effects
    )
    definitions
  pure
    { types: tables.types
    , ctors: tables.ctors
    , effects
    , functions: bodies
    , entry
    }
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
  → Array { name ∷ String, arity ∷ Int }
  → Syntax.FunctionDecl
  → Either Syntax.Diagnostic Signature
resolveSignature types effects function = do
  occurrences ← sortedVariables references function.row
  let written = Array.sortWith sort occurrences
  let
    variables = map name written <> [ "" ]
    sorts = map sort written <> [ Syntax.RowSort ]
    ambient = Just (Resolved.VarId (Array.length written))
    resolved = resolveTypeWith types effects variables ambient
  parameters ← traverse (parameter resolved) function.parameters
  result ← resolved function.result
  row ← resolveRow effects variables ambient resolved function.row
  pure { variables, sorts, parameters, result, row }
  where
  references = Array.snoc (map parameterType function.parameters)
    function.result
  parameterType entry = entry.ty
  name variable = variable.name
  sort variable = variable.sort
  parameter resolved declaration = withType declaration <$> resolved
    declaration.ty
  withType declaration ty =
    { name: declaration.name
    , ty
    , span: declaration.span
    , rowSpan: annotationSpan declaration.ty
    }

writtenSpan ∷ Maybe Syntax.RowRef → Maybe Syntax.Span
writtenSpan = map rowSpan
  where
  rowSpan (Syntax.RowRef span _ _) = span

-- The span of a parameter's written `with` row, if it is an arrow's.
annotationSpan ∷ Syntax.TypeRef → Maybe Syntax.Span
annotationSpan = case _ of
  Syntax.FunRef _ _ (Just (Syntax.RowRef span _ _)) _ → Just span
  _ → Nothing

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
-- to choose its type arguments. Rows are erased first: a row variable is
-- not a type argument (FX001).
entryProblem ∷ Definition → Maybe EntryKind
entryProblem definition
  | not (Array.null definition.function.parameters) = Just EntryParameters
  | isNothing (groundErased definition.signature.result) =
      Just EntryPolymorphic
  | otherwise = Nothing

resolveFunction
  ∷ Array Global
  → Resolved.Tables
  → Array { name ∷ String, arity ∷ Int }
  → Array Resolved.EffectInfo
  → Definition
  → Either Syntax.Diagnostic Resolved.FunctionDecl
resolveFunction globals tables effects effectInfos definition =
  withBody <$> runFresh
    (Array.length parameters)
    (expression scope definition.function.body)
  where
  scope =
    { globals
    , effects
    , effectInfos
    , ctors: tables.ctors
    , locals
    , types: tables.types
    , variables: definition.signature.variables
    }
  parameters = definition.signature.parameters
  locals = Map.fromFoldable (Array.mapWithIndex parameterLocal parameters)
  parameterLocal index parameter =
    Tuple parameter.name (Resolved.LocalId index)
  withBody body =
    { id: Resolved.FunctionId definition.index
    , name: definition.function.name
    , variables: definition.signature.variables
    , sorts: definition.signature.sorts
    , row: definition.signature.row
    , parameters: definition.signature.parameters
    , result: definition.signature.result
    , body
    , span: definition.function.span
    , rowSpan: writtenSpan definition.function.row
    }
