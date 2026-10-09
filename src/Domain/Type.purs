module Domain.Type
  ( module Domain.Ids
  , VarId(..)
  , Ty(..)
  , TyRow
  , Stages
  , Substitution
  , stagesThrough
  , foldStages
  , substitute
  , substituteRow
  ) where

import Prelude
import Prim hiding (Row)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Data.Traversable (mapAccumL)
import Data.Tuple (Tuple(..))
import Domain.Ids (TypeId(..))
import Domain.Row (Label(..), Row(..), closedRow, openRow)

-- A type variable of a signature or declaration, numbered by Resolve.
newtype VarId = VarId Int

derive instance eqVarId ∷ Eq VarId
derive instance ordVarId ∷ Ord VarId

-- One type shape for every phase; `v` is the variables a phase may hold:
-- `VarId` once resolved, `Open` in the checked IR, `Void` when ground.
-- `TFun` is the curried binary arrow with its effect row (FX001): `A -> B
-- -> C` is `TFun A r1 (TFun B r2 C)`, whose chain of results is its
-- spine. A declaration of thousands of parameters has a spine as long, so
-- every pass here walks a spine by a loop and recurses only into
-- parameters, type arguments and label arguments, whose depth the nesting
-- limits bound (design §1, §3). An application's type arguments come
-- before its row arguments, each in declaration order. `TUnit` and
-- `THandler` come last so the order of the earlier ones is kept. A
-- variable has one sort, type or row, by construction.
data Ty v
  = TInt
  | TBool
  | TData TypeId (Array (Ty v)) (Array (TyRow v))
  | TVar v
  | TFun (Ty v) (TyRow v) (Ty v)
  | TUnit
  | THandler (Label (Ty v)) (TyRow v)

type TyRow v = Row (Ty v) v

-- The arrow nodes along a spine, in order, and its final result, for the
-- passes that rebuild an arrow or enter its rows (`foldStages`). Keeping
-- the nodes themselves costs no allocation per arrow.
type Stages v = { arrows ∷ Array (Ty v), result ∷ Ty v }

-- What each variable becomes, by its sort: a type variable a type, a row
-- tail a row, whose labels are spliced after the written ones.
type Substitution v w = { types ∷ v → Ty w, rows ∷ v → TyRow w }

-- Constructors in declaration order, as the derived instance ranked them.
data Head
  = IntHead
  | BoolHead
  | DataHead
  | VarHead
  | FunHead
  | UnitHead
  | HandlerHead

derive instance eqHead ∷ Eq Head
derive instance ordHead ∷ Ord Head

-- The derived instances recursed once per arrow of a spine. These walk
-- spines in step by a loop and keep the derived order: constructors in
-- declaration order, then fields left to right. Applications are compared
-- here, not in a helper, so each level of a deeply applied type costs the
-- frames the derived instance spent (an inferred type 1,000 deep). Rows
-- compare by Array's instances, loops over their labels; an application's
-- rows before its type arguments (`compareRows`), an arrow's after its
-- parameter.
instance eqTy ∷ Eq v ⇒ Eq (Ty v) where
  eq left right = case left, right of
    TData first lefts leftRows, TData second rights rightRows →
      first == second && sameRows leftRows rightRows && lefts == rights
    TFun _ _ _, TFun _ _ _ → sameSpines left right
    THandler one oneRow, THandler other otherRow → one == other
      && oneRow == otherRow
    _, _ → sameLeaf left right

instance ordTy ∷ Ord v ⇒ Ord (Ty v) where
  compare left right = case left, right of
    TData first lefts leftRows, TData second rights rightRows →
      case compare first second, compareRows leftRows rightRows of
        EQ, EQ → compare lefts rights
        EQ, decided → decided
        decided, _ → decided
    TFun _ _ _, TFun _ _ _ → compareSpines left right
    THandler one oneRow, THandler other otherRow → compareParts one other
      oneRow
      otherRow
    _, _ → compareLeaves left right

-- Renaming keeps each variable's sort: a renamed row tail stays a tail.
instance functorTy ∷ Functor Ty where
  map change = substitute { types: TVar <<< change, rows: openRow <<< change }

-- The stages with `look` applied before each step, so a checker can follow
-- a result that is a bound meta into the arrow it stands for. Two loops:
-- one counts the arrows, one takes them; neither recurses. The second
-- takes exactly as many steps as the first counted arrows, through the
-- same `look`, so its no-arrow arm never runs; were it to, it would keep
-- the type as the result and add no stage, never file a result as a
-- parameter.
stagesThrough ∷ ∀ v. (Ty v → Ty v) → Ty v → Stages v
stagesThrough look ty =
  { arrows: Array.catMaybes taken.value, result: taken.accum }
  where
  taken = mapAccumL take ty (Array.replicate (arrowCount look ty) unit)
  take rest _ = case look rest of
    arrow@(TFun _ _ more) → { accum: more, value: Just arrow }
    settled → { accum: settled, value: Nothing }

-- Right to left over a spine's arrow nodes, by Array.foldr (a loop): each
-- arrow's parameter and row with what its result became. Every node is an
-- arrow (`stagesThrough` keeps only arrows), so the other arm never runs.
foldStages ∷ ∀ v b. (Ty v → TyRow v → b → b) → b → Array (Ty v) → b
foldStages stage = Array.foldr each
  where
  each arrow rest = case arrow of
    TFun parameter row _ → stage parameter row rest
    _ → rest

-- The arrows along a spine, through `look`, by a loop.
arrowCount ∷ ∀ v. (Ty v → Ty v) → Ty v → Int
arrowCount look ty = tailRec counted (Tuple 0 ty)
  where
  counted (Tuple found rest) = case look rest of
    TFun _ _ more → Loop (Tuple (found + 1) more)
    _ → Done found

-- Replaces every variable by its sort's image. One pass: an image is not
-- substituted again. Spines are walked by a loop, labels by `map`.
substitute ∷ ∀ v w. Substitution v w → Ty v → Ty w
substitute substitution = case _ of
  TInt → TInt
  TBool → TBool
  TUnit → TUnit
  TData id arguments rows → TData id (map substituted arguments)
    (map (substituteRow substitution) rows)
  TVar variable → substitution.types variable
  THandler label row → THandler (substituteLabel substitution label)
    (substituteRow substitution row)
  arrow@(TFun _ _ _) → substitutedStages (stagesThrough identity arrow)
  where
  substituted part = substitute substitution part
  substitutedStages found = foldStages stage (substituted found.result)
    found.arrows
  stage parameter row rest = TFun (substituted parameter)
    (substituteRow substitution row)
    rest

-- A row's labels, then, for its tail, the tail's image spliced in: its
-- labels appended in order and its own tail the new tail. A row with no
-- label (every row before row syntax) allocates nothing.
substituteRow ∷ ∀ v w. Substitution v w → TyRow v → TyRow w
substituteRow substitution (Row labels tail)
  | Array.null labels = maybe closedRow substitution.rows tail
  | otherwise = maybe (Row written Nothing) spliced tail
      where
      written = map (substituteLabel substitution) labels
      spliced variable = appended (substitution.rows variable)
      appended (Row more rest) = Row (written <> more) rest

substituteLabel ∷ ∀ v w. Substitution v w → Label (Ty v) → Label (Ty w)
substituteLabel substitution (Label effect arguments) =
  Label effect (map (substitute substitution) arguments)

-- Two arrows' spines in step, by a loop, until a parameter or row differs
-- or one side is no longer an arrow.
sameSpines ∷ ∀ v. Eq v ⇒ Ty v → Ty v → Boolean
sameSpines left right = tailRec step (Tuple left right)
  where
  step (Tuple one other) = case one, other of
    TFun first firstRow rest, TFun second secondRow more
      | first == second && sameRow firstRow secondRow →
          Loop (Tuple rest more)
      | otherwise → Done false
    _, _ → Done (one == other)

compareSpines ∷ ∀ v. Ord v ⇒ Ty v → Ty v → Ordering
compareSpines left right = tailRec step (Tuple left right)
  where
  step (Tuple one other) = case one, other of
    TFun first firstRow rest, TFun second secondRow more → continued rest
      more
      (compareParts first second firstRow secondRow)
    _, _ → Done (compare one other)
  continued rest more = case _ of
    EQ → Loop (Tuple rest more)
    decided → Done decided

-- Rows with no label (every row before row syntax) compare by their
-- tails alone.
sameRow ∷ ∀ v. Eq v ⇒ TyRow v → TyRow v → Boolean
sameRow one@(Row oneLabels oneTail) other@(Row otherLabels otherTail)
  | Array.null oneLabels && Array.null otherLabels = oneTail == otherTail
  | otherwise = one == other

-- An application's row arguments, compared before its type arguments so
-- that the type arguments' comparison, which recurses, stays last: a
-- deeply applied type then costs the stack it did before rows (P001 R7
-- headroom). Rows are shallow; none costs no dictionary.
sameRows ∷ ∀ v. Eq v ⇒ Array (TyRow v) → Array (TyRow v) → Boolean
sameRows one other = Array.null one && Array.null other || one == other

compareRows ∷ ∀ v. Ord v ⇒ Array (TyRow v) → Array (TyRow v) → Ordering
compareRows one other =
  if Array.null one && Array.null other then EQ else compare one other

-- The first pair's order, or when equal the second's, computed only then.
compareParts ∷ ∀ a b. Ord a ⇒ Ord b ⇒ a → a → b → b → Ordering
compareParts one other second third = case compare one other of
  EQ → compare second third
  decided → decided

-- Two types that are not both applications, arrows nor handlers.
sameLeaf ∷ ∀ v. Eq v ⇒ Ty v → Ty v → Boolean
sameLeaf one other = case one, other of
  TInt, TInt → true
  TBool, TBool → true
  TUnit, TUnit → true
  TVar first, TVar second → first == second
  _, _ → false

compareLeaves ∷ ∀ v. Ord v ⇒ Ty v → Ty v → Ordering
compareLeaves one other = case one, other of
  TVar first, TVar second → compare first second
  _, _ → compare (headOf one) (headOf other)

headOf ∷ ∀ v. Ty v → Head
headOf = case _ of
  TInt → IntHead
  TBool → BoolHead
  TData _ _ _ → DataHead
  TVar _ → VarHead
  TFun _ _ _ → FunHead
  TUnit → UnitHead
  THandler _ _ → HandlerHead
