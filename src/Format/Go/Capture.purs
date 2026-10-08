-- Free-local sets for match lifting (E005). Lowering builds each
-- expression's set bottom-up from its children's; a lifted match takes the
-- union of its arms' sets as its parameters. Nothing here walks an
-- expression subtree; armFree inspects only the arm's own pattern.
module Format.Go.Capture
  ( Captured
  , Free
  , none
  , read
  , union
  , armFree
  ) where

import Prelude
import Data.Array as Array
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty)
import Domain.Resolved (LocalId(..))

-- A free local: what a lifted match receives as one parameter.
type Captured = { id ∷ LocalId, ty ∷ Ty }

-- The locals an expression reads but does not bind, ascending by LocalId,
-- each once. Lowering computes it bottom-up alongside the code (E005), so a
-- lifted match reads its arms' sets instead of re-scanning its subtree:
-- re-scanning made a 127-deep, 50-arm ladder compile 11 times slower.
type Free = Array Captured

-- Within armFree: a read from the arm's body, or one of its pattern's
-- binders.
type Occurrence = { id ∷ LocalId, ty ∷ Ty, binds ∷ Boolean }

none ∷ Free
none = []

read ∷ LocalId → Ty → Free
read id ty = [ { id, ty } ]

union ∷ Array Free → Free
union frees = Array.nubBy sameLocal
  (Array.sortBy sameLocal (Array.concat frees))

-- An arm's free locals: its body's, minus its pattern's binders. LocalIds
-- are unique per function, so a binder can only be read inside its own arm;
-- subtracting it there leaves the same set as subtracting every binder in
-- the enclosing match. Sorting binders first lets nubBy keep, for each id,
-- its binder when the pattern has one.
armFree ∷ IR.Pattern → Free → Free
armFree pattern body = map captured (Array.filter isRead distinct)
  where
  distinct = Array.nubBy sameLocal
    (Array.sortBy bindersFirst (binders pattern <> map reading body))
  bindersFirst a b = sameLocal a b <> compare b.binds a.binds
  reading local = { id: local.id, ty: local.ty, binds: false }
  isRead occurrence = not occurrence.binds
  captured occurrence = { id: occurrence.id, ty: occurrence.ty }

sameLocal ∷ ∀ r. { id ∷ LocalId | r } → { id ∷ LocalId | r } → Ordering
sameLocal a b = compare (index a.id) (index b.id)

index ∷ LocalId → Int
index (LocalId value) = value

binders ∷ IR.Pattern → Array Occurrence
binders (IR.Pattern pattern) = case pattern.shape of
  IR.Bind id → [ { id, ty: pattern.ty, binds: true } ]
  IR.Ctor _ fields → Array.concatMap binders fields
  _ → []
