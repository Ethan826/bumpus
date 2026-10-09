module Features.Check.Scheme
  ( State
  , Deferral
  , Threaded
  , Scheme
  , start
  , threadAll
  , instantiate
  , at
  , flexible
  , opened
  , resolved
  , headOf
  , tooDeep
  , firstTooDeep
  , holes
  ) where

import Prelude
import Prim hiding (Row)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Syntax (Diagnostic, Span)
import Domain.Type (Ty(..), VarId(..))
import Domain.Row (Row(..), isPure)
import Domain.Type.Parts (children, rowArguments, rowsOf)
import Features.Check.Unify (Flex, Subst, exceedsLimit, resolve, walk)
import Features.Check.Unify as Unify
import Features.Check.Walk (foldTypes, retype)

-- One function's checking state: its substitution and next fresh meta.
-- While a function is checked, a checked-IR type's `Hole m` is the meta m;
-- `holes` renumbers the ones still unsolved once the function is done.
-- `deferrals` are the `defer`s whose Fail label had no settled key when
-- they were checked, for Features.Check.Defer to judge once it is.
type State =
  { subst ∷ Subst, next ∷ Int, deferrals ∷ Array Deferral }

type Deferral = { span ∷ Span, payload ∷ Ty Open }

type Threaded a = { value ∷ a, state ∷ State }

-- One use of a scheme: its variable `VarId i` became meta `base + i`.
type Scheme = { arguments ∷ Array (Ty Open), base ∷ Int }

-- Threads a state through an array, left to right: the checking state, or
-- (for an application) that state with the type still to be applied.
-- Array's traverse nests its applies in a balanced tree, so long arrays
-- (thousands of arms or arguments) neither copy per item nor nest one
-- frame per item.
newtype Thread s a = Thread (s → Either Diagnostic { value ∷ a, state ∷ s })

instance functorThread ∷ Functor (Thread s) where
  map change (Thread run) = Thread (map changed <<< run)
    where
    changed threaded = threaded { value = change threaded.value }

instance applyThread ∷ Apply (Thread s) where
  apply (Thread runChange) (Thread run) = Thread applied
    where
    applied state = runChange state >>= continue
    continue changing = map (changed changing.value) (run changing.state)
    changed change threaded = threaded { value = change threaded.value }

instance applicativeThread ∷ Applicative (Thread s) where
  pure value = Thread threaded
    where
    threaded state = Right { value, state }

start ∷ State
start = { subst: Unify.empty, next: 0, deferrals: [] }

threadAll
  ∷ ∀ s a b
  . (s → a → Either Diagnostic { value ∷ b, state ∷ s })
  → s
  → Array a
  → Either Diagnostic { value ∷ Array b, state ∷ s }
threadAll step state items = running (traverse threaded items)
  where
  threaded item = Thread (flip step item)
  running (Thread run) = run state

-- Fresh metas for a scheme's variables, in their VarId order.
instantiate ∷ ∀ a. Array a → State → Threaded Scheme
instantiate variables state =
  { value: { arguments: Array.mapWithIndex meta variables, base: state.next }
  , state: state { next = state.next + Array.length variables }
  }
  where
  meta index _ = TVar (Hole (state.next + index))

-- A scheme's type at one use.
at ∷ Scheme → Ty VarId → Ty Open
at scheme = map shifted
  where
  shifted (VarId index) = Hole (scheme.base + index)

flexible ∷ Ty Open → Ty Flex
flexible = map toFlex
  where
  toFlex = case _ of
    Checked.Rigid id → Unify.Rigid id
    Hole meta → Unify.Meta meta

opened ∷ Ty Flex → Ty Open
opened = map toOpen
  where
  toOpen = case _ of
    Unify.Rigid id → Checked.Rigid id
    Unify.Meta meta → Hole meta

resolved ∷ Subst → Ty Open → Ty Open
resolved subst ty = opened (resolve subst (flexible ty))

-- The type with its outer chain of bound metas followed, so its head is
-- final; its parts stay unresolved. Only a bound meta is converted, at the
-- cost of its binding's size, so stepping along a long arrow costs nothing
-- per step.
headOf ∷ State → Ty Open → Ty Open
headOf state = case _ of
  TVar (Hole meta) → opened (walk state.subst (TVar (Unify.Meta meta)))
  ty → ty

-- A type with no parts and no meta is one level deep whatever the
-- substitution, so it is answered without converting it (T003): every
-- expression's type is bounded, and most are Int, Bool or rigid.
tooDeep ∷ Subst → Ty Open → Boolean
tooDeep subst = case _ of
  TInt → false
  TBool → false
  TUnit → false
  TVar (Checked.Rigid _) → false
  ty → exceedsLimit subst (flexible ty)

-- The span of the first type, in `foldTypes` order, that is too deep once
-- resolved. A type checked when built can deepen as metas in it are bound
-- later, so a finished body is bounded again before it is resolved.
firstTooDeep ∷ Subst → Checked.Expr → Maybe Span
firstTooDeep subst = foldTypes judged Nothing
  where
  judged found span ty = maybe' (fresh span ty) Just found
  fresh span ty _ = if tooDeep subst ty then Just span else Nothing

-- Renumbers a finished body's unsolved metas as holes 0, 1, …, in the
-- order `foldTypes` first meets them. A body with no hole is kept rather
-- than rebuilt unchanged (T003).
holes ∷ Checked.Expr → Checked.Expr
holes body =
  if Map.isEmpty numbering then body else retype renamed body
  where
  numbering = (foldTypes number { next: 0, seen: Map.empty } body).seen
  number found _ ty = foldHoles numberHole found ty
  renamed ty = map renumber ty
  renumber = case _ of
    Hole meta → Hole (maybe meta identity (Map.lookup meta numbering))
    rigid → rigid

type Numbering = { next ∷ Int, seen ∷ Map Int Int }

numberHole ∷ Numbering → Int → Numbering
numberHole found meta =
  if Map.member meta found.seen then found
  else { next: found.next + 1, seen: Map.insert meta found.next found.seen }

-- A type's holes: its parts', then its rows' (each row's tail, then its
-- label arguments). Type and row metas share one numbering, so a row
-- meta stays apart from every type meta.
foldHoles ∷ ∀ b. (b → Int → b) → b → Ty Open → b
foldHoles step found = case _ of
  TVar (Hole meta) → step found meta
  ty → foldl foldRow (foldl (foldHoles step) found (children ty))
    (rowsOf ty)
  where
  foldRow reached row@(Row _ tail)
    | isPure row = reached
    | otherwise = foldl (foldHoles step)
        (maybe reached (tailHole reached) tail)
        (rowArguments row)
  tailHole reached = case _ of
    Hole meta → step reached meta
    Checked.Rigid _ → reached
