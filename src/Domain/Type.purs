module Domain.Type
  ( TypeId(..)
  , VarId(..)
  , Ty(..)
  , Spine
  , ground
  , spine
  , spineThrough
  , arrows
  , children
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Traversable (mapAccumL, traverse)
import Data.Tuple (Tuple(..))

newtype TypeId = TypeId Int

-- A type variable of a signature or declaration, numbered by Resolve.
newtype VarId = VarId Int

derive instance eqTypeId ∷ Eq TypeId
derive instance ordTypeId ∷ Ord TypeId
derive instance eqVarId ∷ Eq VarId
derive instance ordVarId ∷ Ord VarId

-- One type shape for every phase; `v` is the variables a phase may hold:
-- `VarId` once resolved, `Open` in the checked IR, `Void` when ground.
-- `TFun` is the curried binary arrow: `A -> B -> C` is
-- `TFun A (TFun B C)`, whose chain of results is its spine. A declaration
-- of thousands of parameters has a spine as long, so every pass here walks
-- a spine by a loop and recurses only into parameters and type arguments,
-- whose depth the nesting limits bound (design §1, §3). `TUnit` is the
-- type of `()` (FX001), last so the order of the earlier ones is kept.
data Ty v
  = TInt
  | TBool
  | TData TypeId (Array (Ty v))
  | TVar v
  | TFun (Ty v) (Ty v)
  | TUnit

-- An arrow's parameters, in order, and its final result, which is not an
-- arrow. A type that is not an arrow is its own result.
type Spine v = { parameters ∷ Array (Ty v), result ∷ Ty v }

-- Constructors in declaration order, as the derived instance ranked them.
data Head = IntHead | BoolHead | DataHead | VarHead | FunHead | UnitHead

derive instance eqHead ∷ Eq Head
derive instance ordHead ∷ Ord Head

-- The derived instances recursed once per arrow of a spine. These walk
-- spines in step by a loop and keep the derived order: constructors in
-- declaration order, then fields left to right. Applications are compared
-- here, not in a helper, so each level of a deeply applied type costs the
-- frames the derived instance spent (an inferred type 1,000 deep).
instance eqTy ∷ Eq v ⇒ Eq (Ty v) where
  eq left right = case left, right of
    TData first lefts, TData second rights → first == second
      && lefts == rights
    TFun _ _, TFun _ _ → sameSpines left right
    _, _ → sameLeaf left right

instance ordTy ∷ Ord v ⇒ Ord (Ty v) where
  compare left right = case left, right of
    TData first lefts, TData second rights → case compare first second of
      EQ → compare lefts rights
      decided → decided
    TFun _ _, TFun _ _ → compareSpines left right
    _, _ → compareLeaves left right

instance functorTy ∷ Functor Ty where
  map change ty = substituteWith (TVar <<< change) ty

instance applyTy ∷ Apply Ty where
  apply = ap

instance applicativeTy ∷ Applicative Ty where
  pure = TVar

-- Bind is substitution: each variable is replaced by the type it maps to.
instance bindTy ∷ Bind Ty where
  bind ty substitution = substituteWith substitution ty

instance monadTy ∷ Monad Ty

-- The same type with no variable in it, if it has none.
ground ∷ ∀ v. Ty v → Maybe (Ty Void)
ground = case _ of
  TInt → Just TInt
  TBool → Just TBool
  TUnit → Just TUnit
  TData id arguments → TData id <$> traverse ground arguments
  TVar _ → Nothing
  arrow@(TFun _ _) → groundSpine (spine arrow)
  where
  groundSpine found = arrows <$> traverse ground found.parameters
    <*> ground found.result

spine ∷ ∀ v. Ty v → Spine v
spine = spineThrough identity

-- The spine with `look` applied before each step, so a checker can follow
-- a result that is a bound meta into the arrow it stands for. Two loops:
-- one counts the parameters, one takes them; neither recurses. The second
-- takes exactly as many steps as the first counted arrows, through the
-- same `look`, so its no-arrow arm never runs; were it to, it would keep
-- the type as the result and add no parameter, never file a result as a
-- parameter.
spineThrough ∷ ∀ v. (Ty v → Ty v) → Ty v → Spine v
spineThrough look ty =
  { parameters: Array.catMaybes taken.value, result: taken.accum }
  where
  count = tailRec counted (Tuple 0 ty)
  counted (Tuple found rest) = case look rest of
    TFun _ more → Loop (Tuple (found + 1) more)
    _ → Done found
  taken = mapAccumL take ty (Array.replicate count unit)
  take rest _ = case look rest of
    TFun parameter more → { accum: more, value: Just parameter }
    settled → { accum: settled, value: Nothing }

-- `arrows [a, b] r` is `a -> b -> r`; Array.foldr is a loop.
arrows ∷ ∀ v. Array (Ty v) → Ty v → Ty v
arrows parameters result = Array.foldr TFun result parameters

-- The types a structural pass enters: an application's arguments, or an
-- arrow's parameters followed by its final result (never the arrows of
-- the spine in between, so no pass recurses once per arrow).
children ∷ ∀ v. Ty v → Array (Ty v)
children = case _ of
  TData _ arguments → arguments
  arrow@(TFun _ _) → spineParts (spine arrow)
  _ → []
  where
  spineParts found = Array.snoc found.parameters found.result

substituteWith ∷ ∀ v w. (v → Ty w) → Ty v → Ty w
substituteWith substitution = case _ of
  TInt → TInt
  TBool → TBool
  TUnit → TUnit
  TData id arguments → TData id (map substituted arguments)
  TVar variable → substitution variable
  arrow@(TFun _ _) → substitutedSpine (spine arrow)
  where
  substituted part = substituteWith substitution part
  substitutedSpine found = arrows (map substituted found.parameters)
    (substituted found.result)

-- Two arrows' spines in step, by a loop, until a parameter differs or one
-- side is no longer an arrow.
sameSpines ∷ ∀ v. Eq v ⇒ Ty v → Ty v → Boolean
sameSpines left right = tailRec step (Tuple left right)
  where
  step (Tuple one other) = case one, other of
    TFun first rest, TFun second more
      | first == second → Loop (Tuple rest more)
      | otherwise → Done false
    _, _ → Done (one == other)

compareSpines ∷ ∀ v. Ord v ⇒ Ty v → Ty v → Ordering
compareSpines left right = tailRec step (Tuple left right)
  where
  step (Tuple one other) = case one, other of
    TFun first rest, TFun second more → continued rest more
      (compare first second)
    _, _ → Done (compare one other)
  continued rest more = case _ of
    EQ → Loop (Tuple rest more)
    decided → Done decided

-- Two types that are not both applications nor both arrows.
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
  TData _ _ → DataHead
  TVar _ → VarHead
  TFun _ _ → FunHead
  TUnit → UnitHead
