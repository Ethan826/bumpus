module Domain.Type
  ( TypeId(..)
  , VarId(..)
  , Ty(..)
  , ground
  ) where

import Prelude
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)

newtype TypeId = TypeId Int

-- A type variable of a signature or declaration, numbered by Resolve.
newtype VarId = VarId Int

derive instance eqTypeId ∷ Eq TypeId
derive instance ordTypeId ∷ Ord TypeId
derive instance eqVarId ∷ Eq VarId
derive instance ordVarId ∷ Ord VarId

-- One type shape for every phase; `v` is the variables a phase may hold:
-- `VarId` once resolved, `Open` in the checked IR, `Void` when ground.
data Ty v = TInt | TBool | TData TypeId (Array (Ty v)) | TVar v

derive instance eqTy ∷ Eq v ⇒ Eq (Ty v)
derive instance ordTy ∷ Ord v ⇒ Ord (Ty v)
derive instance functorTy ∷ Functor Ty

instance applyTy ∷ Apply Ty where
  apply = ap

instance applicativeTy ∷ Applicative Ty where
  pure = TVar

-- Bind is substitution: each variable is replaced by the type it maps to.
instance bindTy ∷ Bind Ty where
  bind ty substitution = case ty of
    TInt → TInt
    TBool → TBool
    TData id arguments → TData id (map substituted arguments)
    TVar variable → substitution variable
    where
    substituted argument = bind argument substitution

instance monadTy ∷ Monad Ty

-- The same type with no variable in it, if it has none.
ground ∷ ∀ v. Ty v → Maybe (Ty Void)
ground = case _ of
  TInt → Just TInt
  TBool → Just TBool
  TData id arguments → TData id <$> traverse ground arguments
  TVar _ → Nothing
