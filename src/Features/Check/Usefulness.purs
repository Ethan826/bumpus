module Features.Check.Usefulness (uncovered, useful) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.Traversable (traverse)
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..), Witness(..))
import Domain.Resolved (Ty(..))
import Features.Check.Signature
  ( Head(..)
  , Lookup
  , Signature
  , arity
  , candidates
  , fieldTypes
  , witnessOf
  )

-- Binders and wildcards are indistinguishable to coverage.
data Pat = Any | Headed Head (Array Pat)

type Vector = Array Pat

type Column = { ty ∷ Ty, tys ∷ Array Ty, pat ∷ Pat, rest ∷ Vector }

-- U(P, q): whether some value matches q and no row of P.
useful
  ∷ Signature → Array (Array IR.Pattern) → Array IR.Pattern → Lookup Boolean
useful signature rows q = usefulRows signature (map patternType q)
  (map simplifyRow rows)
  (simplifyRow q)

-- Algorithm I: a witness vector of the given types that no row matches.
uncovered
  ∷ Signature
  → Array (Array IR.Pattern)
  → Array Ty
  → Lookup (Maybe (Array Witness))
uncovered signature rows tys = missing signature tys (map simplifyRow rows)

usefulRows ∷ Signature → Array Ty → Array Vector → Vector → Lookup Boolean
usefulRows signature tys rows q =
  if Array.null rows then Right true
  else column tys q >>= maybe (Right false) (usefulColumn signature rows)

-- An explicit head specializes syntactically; a wildcard head splits only
-- when the column's heads are complete.
usefulColumn ∷ Signature → Array Vector → Column → Lookup Boolean
usefulColumn signature rows split = case split.pat of
  Headed head fields → specialized head fields
  Any → complete signature split.ty (headsOf rows) >>= splitWildcard
  where
  splitWildcard whole =
    if whole then candidates signature split.ty >>= Array.foldM anyUseful
      false
    else usefulRows signature split.tys (defaults rows) split.rest
  specialized head fields = do
    types ← fieldTypes signature head
    specializedRows ← specialize signature head rows
    usefulRows signature (types <> split.tys) specializedRows
      (fields <> split.rest)
  anyUseful found head =
    if found then Right true else arity signature head >>= expanded head
  expanded head count = specialized head (wildcards count)

missing
  ∷ Signature → Array Ty → Array Vector → Lookup (Maybe (Array Witness))
missing signature tys rows =
  maybe' exhausted (missingColumn signature rows) (Array.uncons tys)
  where
  exhausted _ = Right (if Array.null rows then Just [] else Nothing)

-- Canonical choice: the first inhabited head in declaration order.
missingColumn
  ∷ Signature
  → Array Vector
  → { head ∷ Ty, tail ∷ Array Ty }
  → Lookup (Maybe (Array Witness))
missingColumn signature rows split = do
  whole ← complete signature split.head heads
  if whole then candidates signature split.head >>= Array.foldM firstMissing
    Nothing
  else missing signature split.tail (defaults rows) >>= traverse prepend
  where
  heads = headsOf rows
  firstMissing found head = maybe' (expanded head) settled found
  settled witnesses = Right (Just witnesses)
  expanded head _ = do
    types ← fieldTypes signature head
    specializedRows ← specialize signature head rows
    witnesses ← missing signature (types <> split.tail) specializedRows
    traverse (rebuild signature head) witnesses
  prepend witnesses = flip Array.cons witnesses <$> absent signature
    split.head
    heads

-- The head an incomplete column lacks: `_` when no head is present.
absent ∷ Signature → Ty → Array Head → Lookup Witness
absent signature ty heads =
  if Array.null heads then Right WAny
  else choices ty >>= maybe' unfound (opened signature) <<< Array.find lacking
  where
  lacking head = not (Array.elem head heads)
  choices = case _ of
    TInt → Right [ HInt (freeInteger heads 0) ]
    other → candidates signature other
  unfound _ = Left (Internal "Incomplete column lacks no head")

freeInteger ∷ Array Head → Int → Int
freeInteger heads value =
  if Array.elem (HInt value) heads then freeInteger heads (value + 1)
  else value

-- Int has unboundedly many heads, so it is never complete.
complete ∷ Signature → Ty → Array Head → Lookup Boolean
complete signature ty heads =
  if ty == TInt then Right false
  else Array.all present <$> candidates signature ty
  where
  present head = Array.elem head heads

-- Resolution enforces constructor arity, so a head whose field count
-- disagrees with the signature is a compiler bug, never a non-match.
specialize ∷ Signature → Head → Array Vector → Lookup (Array Vector)
specialize signature head rows = do
  count ← arity signature head
  Array.catMaybes <$> traverse (specializeRow count) rows
  where
  specializeRow count row = maybe (Right Nothing) (specializeSplit count)
    (Array.uncons row)
  specializeSplit count split = case split.head of
    Any → Right (Just (wildcards count <> split.tail))
    Headed found fields
      | found /= head → Right Nothing
      | Array.length fields /= count → Left
          (Internal "Coverage field count mismatch")
      | otherwise → Right (Just (fields <> split.tail))

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

-- Types and patterns advance together; unequal lengths are a compiler bug.
column ∷ Array Ty → Vector → Lookup (Maybe Column)
column tys q = maybe' noTypes withTypes (Array.uncons tys)
  where
  noTypes _ = if Array.null q then Right Nothing else mismatch
  withTypes types = maybe mismatch (Right <<< Just <<< split types)
    (Array.uncons q)
  mismatch = Left (Internal "Coverage vector length mismatch")
  split types patterns =
    { ty: types.head, tys: types.tail, pat: patterns.head, rest: patterns.tail }

wildcards ∷ Int → Vector
wildcards count = Array.replicate count Any

opened ∷ Signature → Head → Lookup Witness
opened signature head = arity signature head >>= witnessOf signature head
  <<< flip Array.replicate WAny

-- Folds a head's field witnesses back into one constructor witness.
rebuild ∷ Signature → Head → Array Witness → Lookup (Array Witness)
rebuild signature head witnesses = do
  count ← arity signature head
  when (Array.length witnesses < count)
    (Left (Internal "Witness vector too short"))
  first ← witnessOf signature head (Array.take count witnesses)
  pure (Array.cons first (Array.drop count witnesses))

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
