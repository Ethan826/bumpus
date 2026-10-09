module Features.Resolve.Types (typeTable, resolveType, resolveTypeWith) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (for_, traverse_)
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Control.Monad.Rec.Class (Step(..), tailRec)
import Domain.Problem (DuplicateKind(..), Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Domain.Resolved as Resolved
import Features.Resolve.Row (resolveRow)
import Features.Resolve.Repeated (repeated)
import Features.Resolve.Variables (uniqueTypeParameters)

-- `parameters` are the owner's, the variables its fields may name.
type Owned =
  { id ∷ Resolved.CtorId
  , owner ∷ Resolved.TypeId
  , parameters ∷ Array String
  , decl ∷ Syntax.CtorDecl
  }

-- A function or constructor name, for the shared-namespace duplicate check.
type Global = { name ∷ String, kind ∷ DuplicateKind, span ∷ Syntax.Span }

-- Declarations are checked in the order the spec fixes: types, constructors,
-- functions and parameters, then type parameters, then constructor fields.
typeTable ∷ Syntax.Program → Either Syntax.Diagnostic Resolved.Tables
typeTable program = do
  uniqueTypes program.types
  uniqueCtors program.functions owned
  uniqueFunctions program.functions
  uniqueTypeParameters program.types
  ctors ← traverse (resolveCtor types effects) owned
  pure { types, ctors }
  where
  effects = map summary program.effects
  summary effect =
    { name: effect.name, arity: Array.length effect.parameters }
  owned = ownedCtors program.types
  types = Array.zipWith typeInfo (firstCtors program.types) program.types

-- `variables` are those in scope: `VarId i` is the i-th. A declared type
-- takes exactly as many arguments as it has parameters, else E_ARITY at the
-- whole reference, which is checked before its arguments.
resolveType
  ∷ Array Resolved.TypeInfo
  → Array String
  → Syntax.TypeRef
  → Either Syntax.Diagnostic (Resolved.Ty Resolved.VarId)
resolveType types variables = resolveTypeWith types [] variables Nothing

resolveTypeWith
  ∷ Array Resolved.TypeInfo
  → Array { name ∷ String, arity ∷ Int }
  → Array String
  → Maybe Resolved.VarId
  → Syntax.TypeRef
  → Either Syntax.Diagnostic (Resolved.Ty Resolved.VarId)
resolveTypeWith types effects variables ambient = resolved
  where
  resolved = case _ of
    Syntax.IntRef _ → pure Resolved.TInt
    Syntax.BoolRef _ → pure Resolved.TBool
    Syntax.UnitRef _ → pure Resolved.TUnit
    Syntax.VarRef span name → maybe' (unbound UnboundTypeVariable span name)
      variable
      (Array.elemIndex name variables)
    Syntax.NamedRef span name arguments → maybe'
      (unbound UnboundType span name)
      (applied span name arguments)
      (Array.findIndex (named name) types)
    arrow@(Syntax.FunRef _ _ _ _) → spine arrow
  spine arrow = do
    parameters ← traverse resolved (Syntax.typeRefSpine arrow).parameters
    rows ← traverse (resolveRow effects variables ambient resolved)
      (arrowRows arrow)
    result ← resolved (Syntax.typeRefSpine arrow).result
    pure (Array.foldr stage result (Array.zip parameters rows))
  stage pair result = Resolved.TFun (first pair) (second pair) result
  first (Tuple value _) = value
  second (Tuple _ value) = value
  variable index = pure (Resolved.TVar (Resolved.VarId index))
  named name info = info.name == name
  applied span name arguments index
    | arity index /= Array.length arguments = Left
        (Syntax.problemAt (TypeArguments name) span)
    | otherwise = rowless index <$> traverse resolved arguments
  -- No syntax writes a row argument yet (FX001 Task 4).
  rowless index arguments = Resolved.TData (Resolved.TypeId index) arguments
    []
  arity index = maybe 0 parameterCount (Array.index types index)
  parameterCount info = Array.length info.parameters
  unbound kind span name _ = Left
    (Syntax.problemAt (Unbound kind name) span)

ownedCtors ∷ Array Syntax.TypeDecl → Array Owned
ownedCtors types = Array.mapWithIndex numbered
  (Array.concat (Array.mapWithIndex ownedBy types))
  where
  ownedBy index declaration = map
    (withOwner (Resolved.TypeId index) (map name declaration.parameters))
    declaration.ctors
  name parameter = parameter.name
  withOwner owner parameters decl = { owner, parameters, decl }
  numbered index entry =
    { id: Resolved.CtorId index
    , owner: entry.owner
    , parameters: entry.parameters
    , decl: entry.decl
    }

-- Constructors are numbered in declaration order (ownedCtors), so each type
-- owns the run of ids after all earlier types' constructors. Filtering every
-- constructor per type was O(types × constructors) (A003 final review I3).
firstCtors ∷ Array Syntax.TypeDecl → Array Int
firstCtors types = Array.zipWith sub (Array.scanl add 0 counts) counts
  where
  counts = map ctorCount types
  ctorCount declaration = Array.length declaration.ctors

typeInfo ∷ Int → Syntax.TypeDecl → Resolved.TypeInfo
typeInfo first declaration =
  { name: declaration.name
  , parameters: map parameterName declaration.parameters
  , ctors: Array.mapWithIndex ctorId declaration.ctors
  , span: declaration.span
  }
  where
  ctorId position _ = Resolved.CtorId (first + position)
  parameterName parameter = parameter.name

resolveCtor
  ∷ Array Resolved.TypeInfo
  → Array { name ∷ String, arity ∷ Int }
  → Owned
  → Either Syntax.Diagnostic Resolved.CtorInfo
resolveCtor types effects entry = withFields <$> traverse field
  entry.decl.fields
  where
  field reference = resolveTypeWith types effects entry.parameters Nothing
    reference
  withFields fields =
    { name: entry.decl.name
    , owner: entry.owner
    , fields
    , fieldSyntax: entry.decl.fields
    , span: entry.decl.span
    }

-- Like functions, names are sorted once (Repeated) rather than filtered per
-- declaration, which was quadratic (BACKLOG E002, A003 final review I3).
uniqueTypes ∷ Array Syntax.TypeDecl → Either Syntax.Diagnostic Unit
uniqueTypes types = for_ flagged uniqueType
  where
  flagged = Array.zipWith withFlag (repeated (map name types)) types
  name declaration = declaration.name
  withFlag repeats declaration = { repeats, declaration }
  uniqueType { repeats, declaration } =
    when repeats (duplicate DuplicateType declaration.name declaration.span)

-- Functions and constructors share one namespace, but the program keeps them
-- in separate arrays, so source order is recovered from span offsets: a clash
-- is reported at whichever declaration comes first, whatever its kind. Only
-- the first repeated constructor searches for that declaration.
uniqueCtors
  ∷ Array Syntax.FunctionDecl → Array Owned → Either Syntax.Diagnostic Unit
uniqueCtors functions owned = for_ flagged uniqueCtor
  where
  globals = globalNames functions owned
  flagged = Array.zipWith withFlag (repeated (map name globals)) owned
  name global = global.name
  withFlag repeats entry = { repeats, entry }
  uniqueCtor { repeats, entry }
    | repeats = reportEarliest globals entry.decl.name
    | otherwise = pure unit

reportEarliest ∷ Array Global → String → Either Syntax.Diagnostic Unit
reportEarliest globals clashing = traverse_ report
  (Array.head (Array.sortWith offset (Array.filter named globals)))
  where
  named global = global.name == clashing
  offset global = global.span.start.offset
  report global = duplicate global.kind global.name global.span

-- Constructors first, in id order, then functions.
globalNames ∷ Array Syntax.FunctionDecl → Array Owned → Array Global
globalNames functions owned =
  map ctorGlobal owned <> map functionGlobal functions
  where
  ctorGlobal entry =
    { name: entry.decl.name, kind: DuplicateConstructor, span: entry.decl.span }
  functionGlobal function =
    { name: function.name, kind: DuplicateFunction, span: function.span }

uniqueFunctions
  ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic Unit
uniqueFunctions functions = for_ flagged uniqueFunction
  where
  flagged = Array.zipWith withFlag (repeated (map name functions)) functions
  name function = function.name
  withFlag repeats function = { repeats, function }
  uniqueFunction { repeats, function } = do
    when repeats (duplicate DuplicateFunction function.name function.span)
    uniqueParameters function.parameters

-- The first parameter, in source order, whose name repeats is reported.
-- Filtering the list per parameter was quadratic (20,000 took 2.7 s).
uniqueParameters ∷ Array Syntax.Parameter → Either Syntax.Diagnostic Unit
uniqueParameters parameters = for_ flagged uniqueParameter
  where
  flagged = Array.zipWith withFlag (repeated (map name parameters)) parameters
  name parameter = parameter.name
  withFlag repeats parameter = { repeats, parameter }
  uniqueParameter { repeats, parameter } =
    when repeats (duplicate DuplicateParameter parameter.name parameter.span)

duplicate
  ∷ DuplicateKind → String → Syntax.Span → Either Syntax.Diagnostic Unit
duplicate kind name span = Left
  (Syntax.problemAt (Duplicate kind name) span)

arrowRows ∷ Syntax.TypeRef → Array (Maybe Syntax.RowRef)
arrowRows reference = Array.reverse (tailRec step { rest: reference, rows: [] })
  where
  step found = case found.rest of
    Syntax.FunRef _ _ row rest → Loop
      { rest, rows: Array.cons row found.rows }
    _ → Done found.rows
