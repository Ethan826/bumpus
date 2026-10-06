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

type Owned =
  { id ∷ Resolved.CtorId, owner ∷ Resolved.TypeId, decl ∷ Syntax.CtorDecl }

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
  types = Array.mapWithIndex (typeInfo owned) program.types

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

typeInfo ∷ Array Owned → Int → Syntax.TypeDecl → Resolved.TypeInfo
typeInfo owned index declaration =
  { name: declaration.name
  , ctors: map ctorId (Array.filter ownedHere owned)
  , span: declaration.span
  }
  where
  ownedHere entry = entry.owner == Resolved.TypeId index
  ctorId entry = entry.id

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

uniqueTypes ∷ Array Syntax.TypeDecl → Either Syntax.Diagnostic Unit
uniqueTypes types = for_ types uniqueType
  where
  uniqueType declaration =
    when (Array.length (Array.filter (same declaration) types) > 1)
      (duplicate DuplicateType declaration.name declaration.span)
  same declaration other = other.name == declaration.name

uniqueCtors
  ∷ Array Syntax.FunctionDecl → Array Owned → Either Syntax.Diagnostic Unit
uniqueCtors functions owned = for_ owned uniqueCtor
  where
  uniqueCtor entry =
    when (clashes entry.decl.name)
      (duplicate DuplicateConstructor entry.decl.name entry.decl.span)
  clashes name =
    Array.length (Array.filter (ctorNamed name) owned) > 1
      || Array.any (functionNamed name) functions
  ctorNamed name entry = entry.decl.name == name
  functionNamed name function = function.name == name

uniqueFunctions
  ∷ Array Syntax.FunctionDecl → Either Syntax.Diagnostic Unit
uniqueFunctions functions = for_ functions uniqueFunction
  where
  uniqueFunction function = do
    when (Array.length (Array.filter (namedLike function) functions) > 1)
      (duplicate DuplicateFunction function.name function.span)
    traverse_ (uniqueParameter function.parameters) function.parameters
  namedLike function other = other.name == function.name

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
