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
import Data.Traversable (traverse)
import Data.Tuple (fst, snd)
import Domain.Problem (Problem(..), Witness(..))
import Domain.Checked.Internal (Open)
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeId, TypeInfo)
import Features.Check.Expand (Expansion, application, expand, substitute)
import Features.Check.Inhabited (inhabitation)
import Features.Check.Tables (Lookup, ctorInfo, typeInfo)

-- `inhabited` is indexed by the expansion's constructor numbers: one flag
-- per constructor of each type application.
type Signature =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , expansion ∷ Expansion
  , inhabited ∷ Array Boolean
  }

-- Literals are nullary heads, so one specialization serves every type.
data Head = HCtor CtorId | HInt Int | HBool Boolean

derive instance eqHead ∷ Eq Head

-- The existing fixpoint, run on the expanded tables: inhabitedness per
-- type application (design §5).
buildSignature
  ∷ Array TypeInfo → Array CtorInfo → Array (Ty Open) → Lookup Signature
buildSignature types ctors roots = do
  expansion ← expand types ctors roots
  inhabited ← inhabitation expansion.types expansion.ctors
  pure { types, ctors, expansion, inhabited }

-- Heads whose presence makes a column complete, in declaration order.
-- A type with no inhabited constructor has none, so it is vacuously
-- complete. A rigid variable or a hole is abstract (design §5), and so is
-- an arrow, which only `_` and binders match (FN001 design §3), as is
-- Unit (FX001): none has heads, and `complete` never reads one as
-- complete.
candidates ∷ Signature → Ty Open → Lookup (Array Head)
candidates tables ty = case ty of
  TInt → Right []
  TBool → Right [ HBool true, HBool false ]
  TUnit → Right []
  TData id _ _ → applied tables id ty
  TVar _ → Right []
  TFun _ _ _ → Right []
  THandler _ _ → Right []

-- The declared constructors whose expanded counterparts are inhabited.
applied ∷ Signature → TypeId → Ty Open → Lookup (Array Head)
applied tables id ty = do
  info ← typeInfo tables.types id
  expanded ← application tables.expansion ty
  flags ← traverse (flag tables.inhabited) expanded.ctors
  pure (map (HCtor <<< fst) (Array.filter snd (Array.zip info.ctors flags)))

-- A constructor's declared fields with the column's type arguments
-- substituted; a constructor head on a column that is not data is a bug.
fieldTypes ∷ Signature → Ty Open → Head → Lookup (Array (Ty Open))
fieldTypes tables ty = case _ of
  HCtor id → ctorInfo tables.ctors id >>= fieldsOf
  _ → Right []
  where
  fieldsOf ctor = arguments >>= substituted ctor
  substituted ctor values = traverse (substitute values) ctor.fields
  arguments = case ty of
    TData _ values _ → Right values
    _ → Left (Internal "Constructor head on a type that is not data")

arity ∷ Signature → Head → Lookup Int
arity tables = case _ of
  HCtor id → fieldCount <$> ctorInfo tables.ctors id
  _ → Right 0
  where
  fieldCount ctor = Array.length ctor.fields

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
