module Features.Check.Signature
  ( Signature
  , Head(..)
  , buildSignature
  , candidates
  , fieldTypes
  , arity
  , witnessOf
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Problem (Problem(..), Witness(..))
import Domain.Checked.Internal (Open, rigid)
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeInfo)
import Features.Check.Inhabited (inhabitation)
import Features.Check.Tables (Lookup, ctorInfo, typeInfo)

-- `inhabited` is indexed by CtorId.
type Signature =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , inhabited ∷ Array Boolean
  }

-- Literals are nullary heads, so one specialization serves every type.
data Head = HCtor CtorId | HInt Int | HBool Boolean

derive instance eqHead ∷ Eq Head

buildSignature ∷ Array TypeInfo → Array CtorInfo → Lookup Signature
buildSignature types ctors = withInhabited <$> inhabitation types ctors
  where
  withInhabited inhabited = { types, ctors, inhabited }

-- Heads whose presence makes a column complete, in declaration order.
-- A type with no inhabited constructor has none, so it is vacuously
-- complete. No type variable exists before P001 Task 2; reading one as
-- vacuously complete would be unsound, so it is a compiler bug until
-- coverage learns variables.
candidates ∷ Signature → Ty Open → Lookup (Array Head)
candidates tables = case _ of
  TInt → Right []
  TBool → Right [ HBool true, HBool false ]
  TData id _ → typeInfo tables.types id >>= inhabitedHeads
  TVar _ → Left (Internal "Coverage of a type variable")
  where
  inhabitedHeads info = map HCtor <$> Array.filterA isInhabited info.ctors
  isInhabited id = flag tables.inhabited id

fieldTypes ∷ Signature → Head → Lookup (Array (Ty Open))
fieldTypes tables = case _ of
  HCtor id → fieldsOf <$> ctorInfo tables.ctors id
  _ → Right []
  where
  fieldsOf ctor = map rigid ctor.fields

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

flag ∷ Array Boolean → CtorId → Lookup Boolean
flag inhabited (CtorId index) = maybe' missing Right
  (Array.index inhabited index)
  where
  missing _ = Left (Internal "Invalid constructor id")
