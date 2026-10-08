module Features.Check.Expand
  ( Expansion
  , Key
  , expand
  , application
  , substitute
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (all, foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), isJust, maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..), fst, snd)
import Domain.Checked.Internal (Open)
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), CtorInfo, TypeId(..), TypeInfo)
import Domain.Type (Ty(..), VarId(..), ground)
import Features.Check.Tables (Lookup, ctorInfo, typeInfo)

-- An application with its variables forgotten: rigid variables and holes
-- are one abstract type to coverage (design §5), so `List(a)` in every
-- function and `List(_)` share one key.
type Key = Ty Unit

-- Every application reachable from the roots by unfolding constructor
-- fields, numbered; finite by the instantiation rule (design §4.2). The
-- n-th entry of `types` is application n, listing its own constructors in
-- the declared order; their fields name applications as
-- `TData (TypeId n) []` and the abstract type as Int, which is all
-- Inhabited reads: inhabited and never a data type.
type Expansion =
  { numbers ∷ Map Key Int
  , types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  }

-- `frontier` holds the applications numbered last round, not yet unfolded.
type Discovery = { numbers ∷ Map Key Int, frontier ∷ Array Key }

-- An application's declared constructors, each with its field types
-- substituted.
type Unfolded =
  { info ∷ TypeInfo
  , ctors ∷ Array { ctor ∷ CtorInfo, fields ∷ Array Key }
  }

-- Every declared type whose constructors mention no variable is a root too,
-- so inhabitation still settles over every monomorphic declaration, as it
-- did before applications, including declarations no match reaches.
-- Discovery runs one loop step per round, so a chain of thousands of
-- applications grows neither the stack nor quadratic copies.
expand ∷ Array TypeInfo → Array CtorInfo → Array (Ty Open) → Lookup Expansion
expand types ctors roots = do
  closed ← Array.catMaybes <$> traverse (closedKey ctors) indexed
  numbers ← tailRecM (discover types ctors)
    (admit { numbers: Map.empty, frontier: [] } (closed <> map key roots))
  tables types ctors numbers
  where
  indexed = Array.mapWithIndex Tuple types

-- The expanded type of an applied type; a miss is a compiler bug.
application ∷ Expansion → Ty Open → Lookup TypeInfo
application expansion ty = maybe' unexpanded (typeInfo expansion.types)
  (TypeId <$> Map.lookup (key ty) expansion.numbers)

-- A declared field type with the owner's arguments put for its variables.
substitute ∷ ∀ v. Array (Ty v) → Ty VarId → Lookup (Ty v)
substitute arguments = case _ of
  TInt → Right TInt
  TBool → Right TBool
  TData id inner → TData id <$> traverse (substitute arguments) inner
  TVar (VarId index) → maybe' missing Right (Array.index arguments index)
  where
  missing _ = Left (Internal "Invalid type argument")

key ∷ Ty Open → Key
key = map forget
  where
  forget _ = unit

closedKey ∷ Array CtorInfo → Tuple Int TypeInfo → Lookup (Maybe Key)
closedKey ctors (Tuple index info) = judge <$> traverse (ctorInfo ctors)
  info.ctors
  where
  judge found = if all closedCtor found then Just root else Nothing
  closedCtor ctor = all (isJust <<< ground) ctor.fields
  root = TData (TypeId index) []

-- Numbers the data applications not seen before, in first-seen order.
admit ∷ Discovery → Array Key → Discovery
admit state keys =
  { numbers: foldl number state.numbers fresh, frontier: fresh }
  where
  fresh = Array.filter unseen (Array.nub (Array.filter isData keys))
  unseen found = not (Map.member found state.numbers)
  number numbers found = Map.insert found (Map.size numbers) numbers

discover
  ∷ Array TypeInfo
  → Array CtorInfo
  → Discovery
  → Lookup (Step Discovery (Map Key Int))
discover types ctors state =
  if Array.null state.frontier then pure (Done state.numbers)
  else Loop <<< admit state <<< Array.concat <$> traverse fieldsOf
    state.frontier
  where
  fieldsOf found = Array.concatMap fieldsOfCtor <<< _.ctors <$> unfold types
    ctors
    found
  fieldsOfCtor unfolded = unfolded.fields

-- An application's declared constructors with its arguments substituted.
unfold ∷ Array TypeInfo → Array CtorInfo → Key → Lookup Unfolded
unfold types ctors = case _ of
  TData id arguments → typeInfo types id >>= unfoldInfo ctors arguments
  _ → Left (Internal "Expanded a type that is not data")

unfoldInfo ∷ Array CtorInfo → Array Key → TypeInfo → Lookup Unfolded
unfoldInfo ctors arguments info = do
  found ← traverse (ctorInfo ctors) info.ctors
  applied ← traverse substituted found
  pure { info, ctors: applied }
  where
  substituted ctor = { ctor, fields: _ } <$> traverse
    (substitute arguments)
    ctor.fields

-- Application n's types entry lists constructors numbered after those of
-- applications 0 to n-1.
tables ∷ Array TypeInfo → Array CtorInfo → Map Key Int → Lookup Expansion
tables types ctors numbers = do
  unfolded ← traverse (unfold types ctors) order
  fields ← traverse (traverse expandedFields <<< _.ctors) unfolded
  let starts = Array.cons 0 (Array.scanl add 0 (map Array.length fields))
  pure
    { numbers
    , types: Array.zipWith renumbered starts unfolded
    , ctors: Array.concat (Array.mapWithIndex owned fields)
    }
  where
  order = map fst (Array.sortWith snd (Map.toUnfoldable numbers))
  expandedFields unfolded = Tuple unfolded.ctor <$> traverse (field numbers)
    unfolded.fields
  owned index = map (adopt index)
  adopt index (Tuple ctor expanded) =
    ctor { owner = TypeId index, fields = expanded }
  renumbered start unfolded = unfolded.info
    { ctors = Array.mapWithIndex (offset start) unfolded.ctors }
  offset start index _ = CtorId (start + index)

-- A substituted field as Inhabited reads it.
field ∷ Map Key Int → Key → Lookup (Ty VarId)
field numbers = case _ of
  TInt → Right TInt
  TBool → Right TBool
  TVar _ → Right TInt
  found@(TData _ _) → maybe' unexpanded (Right <<< applied)
    (Map.lookup found numbers)
  where
  applied number = TData (TypeId number) []

isData ∷ Key → Boolean
isData = case _ of
  TData _ _ → true
  _ → false

unexpanded ∷ ∀ a. Unit → Lookup a
unexpanded _ = Left (Internal "Unexpanded type application")
