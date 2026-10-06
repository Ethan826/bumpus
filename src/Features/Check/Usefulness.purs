module Features.Check.Usefulness
  ( Signature
  , Witness(..)
  , inhabitation
  , uncovered
  , useful
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe, maybe')
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeId(..), TypeInfo)

-- `inhabited` is indexed by CtorId.
type Signature =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , inhabited ∷ Array Boolean
  }

data Witness = WAny | WCtor CtorId (Array Witness) | WInt Int | WBool Boolean

-- Literals are nullary heads, so one specialization serves every type.
data Head = HCtor CtorId | HInt Int | HBool Boolean

derive instance eqHead ∷ Eq Head

-- Binders and wildcards are indistinguishable to coverage.
data Pat = Any | Headed Head (Array Pat)

type Vector = Array Pat

type Column = { ty ∷ Ty, tys ∷ Array Ty, pat ∷ Pat, rest ∷ Vector }

-- The least fixed point: start from nothing inhabited and grow.
inhabitation ∷ Array TypeInfo → Array CtorInfo → Array Boolean
inhabitation types ctors = settle (Array.replicate (Array.length ctors) false)
  where
  settle current = if next == current then current else settle next
    where
    next = map (ctorInhabited types current) ctors

-- U(P, q): whether some value matches q and no row of P.
useful ∷ Signature → Array (Array IR.Pattern) → Array IR.Pattern → Boolean
useful signature rows q = usefulRows signature (map patternType q)
  (map simplifyRow rows)
  (simplifyRow q)

-- Algorithm I: a witness vector of the given types that no row matches.
uncovered
  ∷ Signature → Array (Array IR.Pattern) → Array Ty → Maybe (Array Witness)
uncovered signature rows tys = missing signature tys (map simplifyRow rows)

ctorInhabited ∷ Array TypeInfo → Array Boolean → CtorInfo → Boolean
ctorInhabited types inhabited ctor = Array.all fieldInhabited ctor.fields
  where
  fieldInhabited = case _ of
    TInt → true
    TBool → true
    TData (TypeId index) → maybe false anyCtor (Array.index types index)
  anyCtor info = Array.any isInhabited info.ctors
  isInhabited (CtorId index) = Array.index inhabited index == Just true

usefulRows ∷ Signature → Array Ty → Array Vector → Vector → Boolean
usefulRows signature tys rows q =
  if Array.null rows then true
  else maybe false (usefulColumn signature rows) (column tys q)

-- An explicit head specializes syntactically; a wildcard head splits only
-- when the column's heads are complete.
usefulColumn ∷ Signature → Array Vector → Column → Boolean
usefulColumn signature rows split = case split.pat of
  Headed head fields → specialized head fields
  Any →
    if complete signature split.ty (headsOf rows) then
      Array.any expanded (candidates signature split.ty)
    else usefulRows signature split.tys (defaults rows) split.rest
  where
  specialized head fields = usefulRows signature
    (fieldTypes signature head <> split.tys)
    (specialize signature head rows)
    (fields <> split.rest)
  expanded head = specialized head (wildcards (arity signature head))

missing ∷ Signature → Array Ty → Array Vector → Maybe (Array Witness)
missing signature tys rows =
  maybe' exhausted (missingColumn signature rows) (Array.uncons tys)
  where
  exhausted _ = if Array.null rows then Just [] else Nothing

-- Canonical choice: the first inhabited head in declaration order.
missingColumn
  ∷ Signature
  → Array Vector
  → { head ∷ Ty, tail ∷ Array Ty }
  → Maybe (Array Witness)
missingColumn signature rows split =
  if complete signature split.head heads then
    Array.findMap expanded (candidates signature split.head)
  else map prepend (missing signature split.tail (defaults rows))
  where
  heads = headsOf rows
  expanded head = map (rebuild signature head)
    ( missing signature (fieldTypes signature head <> split.tail)
        (specialize signature head rows)
    )
  prepend witnesses = Array.cons (absent signature split.head heads)
    witnesses

-- The head an incomplete column lacks: `_` when no head is present.
absent ∷ Signature → Ty → Array Head → Witness
absent signature ty heads =
  if Array.null heads then WAny
  else maybe WAny (opened signature) (Array.find lacking (choices ty))
  where
  lacking head = not (Array.elem head heads)
  choices = case _ of
    TInt → [ HInt (freeInteger heads 0) ]
    other → candidates signature other

freeInteger ∷ Array Head → Int → Int
freeInteger heads value =
  if Array.elem (HInt value) heads then freeInteger heads (value + 1)
  else value

-- Heads whose presence makes a column complete, in declaration order.
-- A type with no inhabited constructor has none, so it is vacuously
-- complete.
candidates ∷ Signature → Ty → Array Head
candidates signature = case _ of
  TInt → []
  TBool → [ HBool true, HBool false ]
  TData (TypeId index) →
    maybe [] inhabitedHeads (Array.index signature.types index)
  where
  inhabitedHeads info = map HCtor (Array.filter isInhabited info.ctors)
  isInhabited (CtorId index) = Array.index signature.inhabited index ==
    Just true

-- Int has unboundedly many heads, so it is never complete.
complete ∷ Signature → Ty → Array Head → Boolean
complete signature ty heads =
  ty /= TInt && Array.all present (candidates signature ty)
  where
  present head = Array.elem head heads

specialize ∷ Signature → Head → Array Vector → Array Vector
specialize signature head = Array.mapMaybe specializeRow
  where
  specializeRow row = Array.uncons row >>= specializeSplit
  specializeSplit split = case split.head of
    Any → Just (wildcards (arity signature head) <> split.tail)
    Headed found fields →
      if found == head then Just (fields <> split.tail) else Nothing

defaults ∷ Array Vector → Array Vector
defaults = Array.mapMaybe defaultRow
  where
  defaultRow row = Array.uncons row >>= defaultSplit
  defaultSplit split = case split.head of
    Any → Just split.tail
    Headed _ _ → Nothing

headsOf ∷ Array Vector → Array Head
headsOf = Array.mapMaybe firstHead
  where
  firstHead row = Array.head row >>= headOf
  headOf = case _ of
    Any → Nothing
    Headed head _ → Just head

column ∷ Array Ty → Vector → Maybe Column
column tys q = do
  types ← Array.uncons tys
  patterns ← Array.uncons q
  pure
    { ty: types.head, tys: types.tail, pat: patterns.head, rest: patterns.tail }

fieldTypes ∷ Signature → Head → Array Ty
fieldTypes signature = case _ of
  HCtor (CtorId index) → maybe [] fieldsOf (Array.index signature.ctors index)
  _ → []
  where
  fieldsOf ctor = ctor.fields

arity ∷ Signature → Head → Int
arity signature head = Array.length (fieldTypes signature head)

wildcards ∷ Int → Vector
wildcards count = Array.replicate count Any

opened ∷ Signature → Head → Witness
opened signature head = witnessOf head
  (Array.replicate (arity signature head) WAny)

rebuild ∷ Signature → Head → Array Witness → Array Witness
rebuild signature head witnesses = Array.cons
  (witnessOf head (Array.take count witnesses))
  (Array.drop count witnesses)
  where
  count = arity signature head

witnessOf ∷ Head → Array Witness → Witness
witnessOf head fields = case head of
  HCtor id → WCtor id fields
  HInt value → WInt value
  HBool value → WBool value

simplifyRow ∷ Array IR.Pattern → Vector
simplifyRow = map simplify

simplify ∷ IR.Pattern → Pat
simplify (IR.Pattern pattern) = case pattern.shape of
  IR.Wildcard → Any
  IR.Bind _ → Any
  IR.IntLit value → Headed (HInt value) []
  IR.BoolLit value → Headed (HBool value) []
  IR.Ctor id fields → Headed (HCtor id) (map simplify fields)

patternType ∷ IR.Pattern → Ty
patternType (IR.Pattern pattern) = pattern.ty
