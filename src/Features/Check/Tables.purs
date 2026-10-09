module Features.Check.Tables (Lookup, typeInfo, ctorInfo, ownerType) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Domain.Problem (Problem(..))
import Domain.Resolved
  ( CtorId(..)
  , CtorInfo
  , Ty(..)
  , TypeId(..)
  , TypeInfo
  , VarId(..)
  )
import Domain.Row (Row(..))
import Domain.Syntax as Syntax

-- Ids come from the checker's own tables, so a failed lookup is a compiler
-- bug. It is reported as E_INTERNAL, never read as "uninhabited" or `_`.
type Lookup a = Either Problem a

typeInfo ∷ Array TypeInfo → TypeId → Lookup TypeInfo
typeInfo types (TypeId index) = maybe' missing Right
  (Array.index types index)
  where
  missing _ = Left (Internal "Invalid type id")

ctorInfo ∷ Array CtorInfo → CtorId → Lookup CtorInfo
ctorInfo ctors (CtorId index) = maybe' missing Right
  (Array.index ctors index)
  where
  missing _ = Left (Internal "Invalid constructor id")

-- A constructor's owner applied to its own variables: a type argument per
-- type parameter and a row argument per row parameter, in declaration
-- order. Construction and patterns both instantiate it, so a row-
-- parameterized type is the same type in both.
ownerType ∷ TypeId → TypeInfo → Ty VarId
ownerType owner info = TData owner (map variable (positions Syntax.TypeSort))
  (map row (positions Syntax.RowSort))
  where
  variable position = TVar (VarId position)
  row position = Row [] (Just (VarId position))
  positions sort = Array.mapMaybe identity
    (Array.mapWithIndex (select sort) info.sorts)
  select sort position sortValue =
    if sortValue == sort then Just position else Nothing
