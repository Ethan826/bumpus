module Features.Check.Signature
  ( Signature
  , Head(..)
  , Lookup
  , buildSignature
  , candidates
  , fieldTypes
  , arity
  , witnessOf
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (and, or)
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Problem (Problem(..), Witness(..))
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeId(..), TypeInfo)

-- `inhabited` is indexed by CtorId.
type Signature =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , inhabited ∷ Array Boolean
  }

-- Ids come from the checker's own tables, so a failed lookup is a compiler
-- bug. It is reported as E_INTERNAL, never read as "uninhabited" or `_`.
type Lookup a = Either Problem a

-- Literals are nullary heads, so one specialization serves every type.
data Head = HCtor CtorId | HInt Int | HBool Boolean

derive instance eqHead ∷ Eq Head

-- Inhabitation is the least fixed point: start from nothing and grow.
buildSignature ∷ Array TypeInfo → Array CtorInfo → Lookup Signature
buildSignature types ctors = withInhabited <$> settle
  (Array.replicate (Array.length ctors) false)
  where
  settle current = do
    next ← traverse (ctorInhabited types current) ctors
    if next == current then pure current else settle next
  withInhabited inhabited = { types, ctors, inhabited }

-- Heads whose presence makes a column complete, in declaration order.
-- A type with no inhabited constructor has none, so it is vacuously
-- complete.
candidates ∷ Signature → Ty → Lookup (Array Head)
candidates tables = case _ of
  TInt → Right []
  TBool → Right [ HBool true, HBool false ]
  TData id → typeInfo tables.types id >>= inhabitedHeads
  where
  inhabitedHeads info = map HCtor <$> Array.filterA isInhabited info.ctors
  isInhabited id = flag tables.inhabited id

fieldTypes ∷ Signature → Head → Lookup (Array Ty)
fieldTypes tables = case _ of
  HCtor id → fieldsOf <$> ctorInfo tables.ctors id
  _ → Right []
  where
  fieldsOf ctor = ctor.fields

arity ∷ Signature → Head → Lookup Int
arity tables head = Array.length <$> fieldTypes tables head

-- A witness carries the constructor's name, so Format needs no tables.
witnessOf ∷ Signature → Head → Array Witness → Lookup Witness
witnessOf tables head fields = case head of
  HCtor id → named <$> ctorInfo tables.ctors id
  HInt value → Right (WInt value)
  HBool value → Right (WBool value)
  where
  named ctor = WCtor ctor.name fields

ctorInhabited
  ∷ Array TypeInfo → Array Boolean → CtorInfo → Lookup Boolean
ctorInhabited types inhabited ctor = and <$> traverse fieldInhabited
  ctor.fields
  where
  fieldInhabited = case _ of
    TInt → Right true
    TBool → Right true
    TData id → typeInfo types id >>= anyInhabited
  anyInhabited info = or <$> traverse (flag inhabited) info.ctors

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

flag ∷ Array Boolean → CtorId → Lookup Boolean
flag inhabited (CtorId index) = maybe' missing Right
  (Array.index inhabited index)
  where
  missing _ = Left (Internal "Invalid constructor id")
