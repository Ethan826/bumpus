module Features.Resolve.Scope (Scope) where

import Data.Map (Map)
import Domain.Resolved (Global)
import Domain.Resolved as Resolved

type Scope =
  { globals ∷ Array Global
  , ctors ∷ Array Resolved.CtorInfo
  , locals ∷ Map String Resolved.LocalId
  , types ∷ Array Resolved.TypeInfo
  , effects ∷ Array { name ∷ String, arity ∷ Int }
  , effectInfos ∷ Array Resolved.EffectInfo
  , variables ∷ Array String
  }
