module Format.Go.Capture (Captured, captures) where

import Prelude
import Data.Array as Array
import Domain.IR.Internal as IR
import Domain.Resolved (LocalId(..), Ty)

-- A local that a lifted match receives as a parameter.
type Captured = { id ∷ LocalId, ty ∷ Ty }

-- A read of a local, or the pattern binder that introduces one.
type Occurrence = { id ∷ LocalId, ty ∷ Ty, binds ∷ Boolean }

-- The locals a lifted match reads but does not bind, in LocalId order (E005).
-- Its own scrutinee runs at the call site, so only its arms count, but all
-- of them: nested scrutinees and nested arm bodies run inside the lifted
-- function, so an outer binder read only by an inner scrutinee is captured.
-- LocalIds are unique per function, so a binder anywhere in the arms is
-- never a capture. Sorting binders first lets nubBy keep, for each id, its
-- binder when the match has one.
captures ∷ Array IR.Arm → Array Captured
captures arms = map captured (Array.filter isRead distinct)
  where
  distinct = Array.nubBy sameLocal
    (Array.sortBy bindersFirst (Array.concatMap armOccurrences arms))
  sameLocal a b = compare (index a.id) (index b.id)
  bindersFirst a b = sameLocal a b <> compare b.binds a.binds
  isRead occurrence = not occurrence.binds
  captured occurrence = { id: occurrence.id, ty: occurrence.ty }

index ∷ LocalId → Int
index (LocalId value) = value

armOccurrences ∷ IR.Arm → Array Occurrence
armOccurrences arm = binders arm.pattern <> occurrences arm.body

occurrences ∷ IR.Expr → Array Occurrence
occurrences (IR.Expr term) = case term.node of
  IR.Local id → [ { id, ty: term.ty, binds: false } ]
  IR.Call _ arguments → within arguments
  IR.Construct _ arguments → within arguments
  IR.Add left right → within [ left, right ]
  IR.Compare _ left right → within [ left, right ]
  IR.If condition yes no → within [ condition, yes, no ]
  IR.Match scrutinee arms → nested scrutinee arms
  _ → []
  where
  within = Array.concatMap occurrences

-- A nested match's scrutinee is evaluated inside the enclosing lifted
-- function, so its reads count as the enclosing match's.
nested ∷ IR.Expr → Array IR.Arm → Array Occurrence
nested scrutinee arms = occurrences scrutinee
  <> Array.concatMap armOccurrences arms

binders ∷ IR.Pattern → Array Occurrence
binders (IR.Pattern pattern) = case pattern.shape of
  IR.Bind id → [ { id, ty: pattern.ty, binds: true } ]
  IR.Ctor _ fields → Array.concatMap binders fields
  _ → []
