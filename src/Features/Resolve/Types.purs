module Features.Resolve.Types (typeTable, resolveType) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (for_, traverse_)
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Problem (DuplicateKind(..), Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Domain.Resolved as Resolved
import Features.Resolve.Repeated (repeated)

type Owned =
  { id ∷ Resolved.CtorId, owner ∷ Resolved.TypeId, decl ∷ Syntax.CtorDecl }

-- A function or constructor name, for the shared-namespace duplicate check.
type Global = { name ∷ String, kind ∷ DuplicateKind, span ∷ Syntax.Span }

-- Declarations are checked in the order the spec fixes: types, constructors,
-- functions and parameters, then constructor fields.
typeTable ∷ Syntax.Program → Either Syntax.Diagnostic Resolved.Tables
typeTable program = do
  uniqueTypes program.types
  uniqueCtors program.functions owned
  uniqueFunctions program.functions
  ctors ← traverse (resolveCtor types) owned
  pure { types, ctors }
  where
  owned = ownedCtors program.types
  types = Array.zipWith typeInfo (firstCtors program.types) program.types

resolveType
  ∷ Array Resolved.TypeInfo
  → Syntax.TypeRef
  → Either Syntax.Diagnostic Resolved.Ty
resolveType types = case _ of
  Syntax.IntRef _ → pure Resolved.TInt
  Syntax.BoolRef _ → pure Resolved.TBool
  Syntax.NamedRef span name → maybe' (missing span name) found
    (Array.findIndex (named name) types)
  where
  named name info = info.name == name
  found index = pure (Resolved.TData (Resolved.TypeId index))
  missing span name _ = Left
    (Syntax.problemAt (Unbound UnboundType name) span)

ownedCtors ∷ Array Syntax.TypeDecl → Array Owned
ownedCtors types = Array.mapWithIndex numbered
  (Array.concat (Array.mapWithIndex ownedBy types))
  where
  ownedBy index declaration = map
    (withOwner (Resolved.TypeId index))
    declaration.ctors
  withOwner owner decl = { owner, decl }
  numbered index entry =
    { id: Resolved.CtorId index, owner: entry.owner, decl: entry.decl }

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
  , ctors: Array.mapWithIndex ctorId declaration.ctors
  , span: declaration.span
  }
  where
  ctorId position _ = Resolved.CtorId (first + position)

resolveCtor
  ∷ Array Resolved.TypeInfo
  → Owned
  → Either Syntax.Diagnostic Resolved.CtorInfo
resolveCtor types entry = withFields <$> traverse field entry.decl.fields
  where
  field reference = resolveType types reference
  withFields fields =
    { name: entry.decl.name
    , owner: entry.owner
    , fields
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
    traverse_ (uniqueParameter function.parameters) function.parameters

uniqueParameter
  ∷ Array Syntax.Parameter → Syntax.Parameter → Either Syntax.Diagnostic Unit
uniqueParameter parameters parameter =
  when (Array.length (Array.filter sameName parameters) > 1)
    (duplicate DuplicateParameter parameter.name parameter.span)
  where
  sameName other = other.name == parameter.name

duplicate
  ∷ DuplicateKind → String → Syntax.Span → Either Syntax.Diagnostic Unit
duplicate kind name span = Left
  (Syntax.problemAt (Duplicate kind name) span)
