module Features.Check.Missing (uncovered) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (traverse)
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..), Witness(..))
import Domain.Resolved (Ty(..))
import Features.Check.Matrix (Vector, complete, defaults, headsOf, simplifyRow)
import Features.Check.Matrix (specialize) as Matrix
import Features.Check.Search (Stack(..))
import Features.Check.Signature
  ( Head(..)
  , Signature
  , arity
  , candidates
  , fieldTypes
  , witnessOf
  )
import Features.Check.Tables (Lookup)

type Task = { tys ∷ Array Ty, rows ∷ Array Vector }

type Split = { head ∷ Ty, tail ∷ Array Ty }

-- A complete column: the heads not yet tried, in declaration order.
type Branch = { rows ∷ Array Vector, split ∷ Split, heads ∷ Array Head }

-- What waits on a sub-problem's witness vector: the next head of a complete
-- column, folding a head's fields into one witness, or the absent head of
-- an incomplete column.
data Frame = Alternatives Branch | Rebuild Head | Prepend Ty (Array Head)

data Mode = Descend Task | Ascend (Maybe (Array Witness))

type State = { mode ∷ Mode, frames ∷ Stack Frame }

type Found = Maybe (Array Witness)

-- Algorithm I: a witness vector of the given types that no row matches.
-- The canonical choice is the first inhabited head in declaration order.
-- Continuations live on an explicit stack: recursion grew the JavaScript
-- stack per column and overflowed at about 1,600 (G001 final review I1).
uncovered
  ∷ Signature → Array (Array IR.Pattern) → Array Ty → Lookup Found
uncovered signature rows tys = tailRecM (step signature)
  { mode: Descend { tys, rows: map simplifyRow rows }, frames: Bottom }

step ∷ Signature → State → Lookup (Step State Found)
step signature state = case state.mode of
  Descend problem → descend signature state.frames problem
  Ascend found → ascend signature found state.frames

descend ∷ Signature → Stack Frame → Task → Lookup (Step State Found)
descend signature frames problem =
  maybe' exhausted split (Array.uncons problem.tys)
  where
  exhausted _ = pure (Loop (ascending frames vacant))
  vacant = if Array.null problem.rows then Just [] else Nothing
  split types = complete signature types.head heads >>= judge types
  heads = headsOf problem.rows
  judge types whole =
    if whole then fork types <$> candidates signature types.head
    else pure (Loop (incomplete types))
  fork types choices = Loop $ ascending
    ( Push (Alternatives { rows: problem.rows, split: types, heads: choices })
        frames
    )
    Nothing
  incomplete types =
    { mode: Descend { tys: types.tail, rows: defaults problem.rows }
    , frames: Push (Prepend types.head heads) frames
    }

ascend ∷ Signature → Found → Stack Frame → Lookup (Step State Found)
ascend signature found = case _ of
  Bottom → pure (Done found)
  Push (Alternatives branch) rest →
    maybe' (retry branch rest) (settled rest) found
  Push (Rebuild head) rest →
    Loop <<< ascending rest <$> traverse (rebuild signature head) found
  Push (Prepend ty heads) rest →
    Loop <<< ascending rest <$> traverse (prepend ty heads) found
  where
  settled rest witnesses = pure (Loop (ascending rest (Just witnesses)))
  retry branch rest _ = maybe' (giveUp rest) (attempt signature branch rest)
    (Array.uncons branch.heads)
  giveUp rest _ = pure (Loop (ascending rest Nothing))
  prepend ty heads witnesses = flip Array.cons witnesses <$> absent signature
    ty
    heads

attempt
  ∷ Signature
  → Branch
  → Stack Frame
  → { head ∷ Head, tail ∷ Array Head }
  → Lookup (Step State Found)
attempt signature branch rest split = do
  types ← fieldTypes signature split.head
  rows ← Matrix.specialize signature split.head branch.rows
  pure $ Loop
    { mode: Descend { tys: types <> branch.split.tail, rows }
    , frames: Push (Rebuild split.head) (Push (Alternatives remaining) rest)
    }
  where
  remaining = branch { heads = split.tail }

ascending ∷ Stack Frame → Found → State
ascending frames found = { mode: Ascend found, frames }

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
