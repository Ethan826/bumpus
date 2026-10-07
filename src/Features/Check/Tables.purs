module Features.Check.Tables (Lookup, typeInfo, ctorInfo) where

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), CtorInfo, TypeId(..), TypeInfo)

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
