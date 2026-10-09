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
import Data.String.Common (joinWith)
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..), fst, snd)
import Domain.Checked.Internal (Open)
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), CtorInfo, TypeId(..), TypeInfo)
import Domain.Row (Label(..), closedRow)
import Domain.Type (Ty(..), VarId(..))
import Domain.Type.Parts (arrows, children, ground, spine)
import Features.Check.Tables (Lookup, ctorInfo, typeInfo)

-- An application with its variables forgotten: rigid variables and holes
-- are one abstract type to coverage (design §5), so `List(a)` in every
-- function and `List(_)` share one key.
type Key = Ty Unit

-- Every application reachable from the roots by unfolding constructor
-- fields, numbered by its spelling; finite by the instantiation rule
-- (design §4.2). The n-th entry of `types` is application n, listing its
-- own constructors in the declared order; their fields name applications as
-- `TData (TypeId n) []` and the abstract type and every arrow as Int, which
-- is all Inhabited reads: inhabited and never a data type (an arrow is
-- always inhabited, design §3, so its parts are never unfolded).
type Expansion =
  { numbers ∷ Map String Int
  , types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  }

-- `frontier` holds the applications numbered last round, not yet unfolded;
-- `keys` gives each number its application.
type Discovery =
  { numbers ∷ Map String Int, keys ∷ Map Int Key, frontier ∷ Array Key }

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
  found ← tailRecM (discover types ctors)
    (admit start (closed <> map key roots))
  tables types ctors found
  where
  indexed = Array.mapWithIndex Tuple types
  start = { numbers: Map.empty, keys: Map.empty, frontier: [] }

-- The expanded type of an applied type; a miss is a compiler bug.
application ∷ Expansion → Ty Open → Lookup TypeInfo
application expansion ty = maybe' unexpanded (typeInfo expansion.types)
  (TypeId <$> Map.lookup (spelling (key ty)) expansion.numbers)

-- A declared field type with the owner's arguments put for its variables.
-- Coverage never reads a row (an arrow or handler is abstract to it), so
-- rows are left out: arrows pure, applications without row arguments.
substitute ∷ ∀ v. Array (Ty v) → Ty VarId → Lookup (Ty v)
substitute arguments = case _ of
  TInt → Right TInt
  TBool → Right TBool
  TUnit → Right TUnit
  TData id inner _ → rowless id <$> traverse (substitute arguments) inner
  TVar (VarId index) → maybe' missing Right (Array.index arguments index)
  THandler (Label effect inner) _ → handler effect <$> traverse
    (substitute arguments)
    inner
  arrow@(TFun _ _ _) → substituteSpine (spine arrow)
  where
  rowless id inner = TData id inner []
  handler effect inner = THandler (Label effect inner) closedRow
  missing _ = Left (Internal "Invalid type argument")
  substituteSpine found = arrows
    <$> traverse (substitute arguments) found.parameters
    <*> substitute arguments found.result

key ∷ Ty Open → Key
key = map forget
  where
  forget _ = unit

-- A key's canonical text, the map key for its number. Comparing two
-- spellings is one native string comparison; comparing two keys walked
-- both through Ord dictionaries, and with applications nested a thousand
-- deep that comparison was nearly all of checking (P001 final fix). An
-- arrow is `f(` its parameters and final result `)`, which no data
-- application's spelling (a number first) can be.
spelling ∷ Key → String
spelling = case _ of
  TInt → "i"
  TBool → "b"
  TUnit → "u"
  TVar _ → "v"
  TData (TypeId id) arguments _ → show id <> "("
    <> joinWith "," (map spelling arguments)
    <> ")"
  arrow@(TFun _ _ _) → "f(" <> joinWith "," (map spelling (children arrow))
    <> ")"
  handler@(THandler _ _) → "h("
    <> joinWith ","
      (map spelling (children handler))
    <> ")"

closedKey ∷ Array CtorInfo → Tuple Int TypeInfo → Lookup (Maybe Key)
closedKey ctors (Tuple index info) = judge <$> traverse (ctorInfo ctors)
  info.ctors
  where
  judge found = if all closedCtor found then Just root else Nothing
  closedCtor ctor = all (isJust <<< ground) ctor.fields
  root = TData (TypeId index) [] []

-- Numbers the data applications not seen before, in first-seen order.
admit ∷ Discovery → Array Key → Discovery
admit state keys = numbered (state { frontier = map snd fresh })
  where
  spelled = map withSpelling (Array.filter isData keys)
  withSpelling found = Tuple (spelling found) found
  fresh = Array.filter unseen (Array.nubBy (comparing fst) spelled)
  unseen (Tuple text _) = not (Map.member text state.numbers)
  numbered start = foldl number start fresh
  number reached (Tuple text found) = reached
    { numbers = Map.insert text (Map.size reached.numbers) reached.numbers
    , keys = Map.insert (Map.size reached.numbers) found reached.keys
    }

discover
  ∷ Array TypeInfo
  → Array CtorInfo
  → Discovery
  → Lookup (Step Discovery Discovery)
discover types ctors state =
  if Array.null state.frontier then pure (Done state)
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
  TData id arguments _ → typeInfo types id >>= unfoldInfo ctors arguments
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
tables ∷ Array TypeInfo → Array CtorInfo → Discovery → Lookup Expansion
tables types ctors found = do
  unfolded ← traverse (unfold types ctors) order
  fields ← traverse (traverse expandedFields <<< _.ctors) unfolded
  let starts = Array.cons 0 (Array.scanl add 0 (map Array.length fields))
  pure
    { numbers: found.numbers
    , types: Array.zipWith renumbered starts unfolded
    , ctors: Array.concat (Array.mapWithIndex owned fields)
    }
  where
  order = map snd (Map.toUnfoldable found.keys ∷ Array (Tuple Int Key))
  expandedFields unfolded = Tuple unfolded.ctor <$> traverse
    (field found.numbers)
    unfolded.fields
  owned index = map (adopt index)
  adopt index (Tuple ctor expanded) =
    ctor { owner = TypeId index, fields = expanded }
  renumbered start unfolded = unfolded.info
    { ctors = Array.mapWithIndex (offset start) unfolded.ctors }
  offset start index _ = CtorId (start + index)

-- A substituted field as Inhabited reads it.
field ∷ Map String Int → Key → Lookup (Ty VarId)
field numbers = case _ of
  TInt → Right TInt
  TBool → Right TBool
  TUnit → Right TUnit
  TVar _ → Right TInt
  TFun _ _ _ → Right TInt
  THandler _ _ → Right TInt
  found@(TData _ _ _) → maybe' unexpanded (Right <<< applied)
    (Map.lookup (spelling found) numbers)
  where
  applied number = TData (TypeId number) [] []

isData ∷ Key → Boolean
isData = case _ of
  TData _ _ _ → true
  _ → false

unexpanded ∷ ∀ a. Unit → Lookup a
unexpanded _ = Left (Internal "Unexpanded type application")
