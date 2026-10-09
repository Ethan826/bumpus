module Features.Resolve.TypeValidation
  ( uniqueTypes
  , uniqueCtors
  , uniqueFunctions
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (for_, traverse_)
import Domain.Problem (DuplicateKind(..), Problem(..))
import Domain.Syntax as Syntax
import Features.Resolve.Repeated (repeated)

type Global = { name ∷ String, kind ∷ DuplicateKind, span ∷ Syntax.Span }

uniqueTypes ∷ Array Syntax.TypeDecl → Either Syntax.Diagnostic Unit
uniqueTypes types = for_ flagged uniqueType
  where
  flagged = Array.zipWith withFlag (repeated (map typeName types)) types
  typeName declaration = declaration.name
  withFlag repeats declaration = { repeats, declaration }
  uniqueType { repeats, declaration } =
    when repeats (duplicate DuplicateType declaration.name declaration.span)

uniqueCtors
  ∷ Array Syntax.FunctionDecl
  → Array Syntax.TypeDecl
  → Either Syntax.Diagnostic Unit
uniqueCtors functions types = for_ flagged uniqueCtor
  where
  globals = globalNames functions types
  constructors = Array.concatMap constructorsOf types
  globalFlags = repeated (map globalName globals)
  constructorFlags = Array.take (Array.length constructors) globalFlags
  flagged = Array.zipWith withFlag
    constructorFlags
    constructors
  constructorsOf declaration = declaration.ctors
  globalName global = global.name
  withFlag repeats entry = { repeats, entry }
  uniqueCtor { repeats, entry }
    | repeats = reportEarliest globals entry.name
    | otherwise = Right unit

reportEarliest ∷ Array Global → String → Either Syntax.Diagnostic Unit
reportEarliest globals clashing = traverse_ report
  (Array.head (Array.sortWith offset (Array.filter named globals)))
  where
  named global = global.name == clashing
  offset global = global.span.start.offset
  report global = duplicate global.kind global.name global.span

globalNames ∷ Array Syntax.FunctionDecl → Array Syntax.TypeDecl → Array Global
globalNames functions types =
  map ctorGlobal (Array.concatMap constructorsOf types)
    <> map functionGlobal functions
  where
  constructorsOf declaration = declaration.ctors
  ctorGlobal ctor =
    { name: ctor.name, kind: DuplicateConstructor, span: ctor.span }
  functionGlobal function =
    { name: function.name, kind: DuplicateFunction, span: function.span }

uniqueFunctions ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic Unit
uniqueFunctions functions = for_ flagged uniqueFunction
  where
  flagged = Array.zipWith withFlag
    (repeated (map functionName functions))
    functions
  functionName function = function.name
  withFlag repeats function = { repeats, function }
  uniqueFunction { repeats, function } = do
    when repeats (duplicate DuplicateFunction function.name function.span)
    uniqueParameters function.parameters

uniqueParameters ∷ Array Syntax.Parameter → Either Syntax.Diagnostic Unit
uniqueParameters parameters = for_ flagged uniqueParameter
  where
  flagged = Array.zipWith withFlag
    (repeated (map parameterName parameters))
    parameters
  parameterName parameter = parameter.name
  withFlag repeats parameter = { repeats, parameter }
  uniqueParameter { repeats, parameter } = when repeats
    (duplicate DuplicateParameter parameter.name parameter.span)

duplicate
  ∷ DuplicateKind
  → String
  → Syntax.Span
  → Either Syntax.Diagnostic Unit
duplicate kind name span = Left
  (Syntax.problemAt (Duplicate kind name) span)
