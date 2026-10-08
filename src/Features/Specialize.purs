module Features.Specialize
  ( Key
  , specialize
  , specializeWith
  , specializationKeys
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple, snd)
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Resolved (FunctionId(..))
import Domain.Syntax (Diagnostic, Span, origin, problemAt)
import Domain.Type (Ty(..), TypeId(..), arrows)
import Features.Specialize.Body (fillFunction)
import Features.Specialize.Copy (run)
import Features.Specialize.Intern (Lowered, loweredType)
import Features.Specialize.Keys (Env, State, Work)
import Features.Specialize.Lower (fillType)
import Features.Specialize.Seeds (environment, seeded)

-- A key as tests see it: the checked declaration's id and its ground type
-- arguments (empty for a monomorphic declaration).
type Key =
  { declaration ∷ Int, function ∷ Boolean, arguments ∷ Array (Ty Void) }

-- Whole-program specialization (design §6): one copy of each function and
-- type per key reachable from the monomorphic seeds; holes become Int.
specialize ∷ Checked.Program → Either Diagnostic IR.Program
specialize = specializeWith TInt

-- `representative` replaces every hole. Programs print the same for any
-- representative (§6); tests pass another one to check it.
specializeWith ∷ Ty Void → Checked.Program → Either Diagnostic IR.Program
specializeWith representative checked = do
  finished ← specialized representative checked
  pure
    ( IR.Program
        { types: values finished.state.types
        , ctors: values finished.state.ctors
        , functions: values finished.state.functions
        , entry: finished.entry
        }
    )

-- Every key, types then functions, each in output-id order. A key's
-- arguments name only earlier output types, so one pass rebuilds them; an
-- arrow is rebuilt along its spine by a loop.
specializationKeys ∷ Checked.Program → Either Diagnostic (Array Key)
specializationKeys checked = do
  finished ← specialized TInt checked
  let made = values finished.state.work
  let types = Array.filter isType made
  grounds ← foldl groundOf (Right Map.empty) types
  traverse (key grounds) (types <> Array.filter isFunction made)
  where
  isType work = not work.function
  isFunction work = work.function

type Finished = { state ∷ State, entry ∷ FunctionId }

specialized ∷ Ty Void → Checked.Program → Either Diagnostic Finished
specialized representative checked@(Checked.Program program) = do
  entry ← maybe' missingEntry Right
    (join (Array.index env.monoFunctions (functionIndex program.entry)))
  state ← tailRecM (next env) { index: 0, state: seeded env }
  pure { state, entry: FunctionId entry }
  where
  env = environment representative checked
  missingEntry _ = Left
    (problemAt (Internal "Invalid entry") { start: origin, end: origin })

-- The worklist (design §6): work items are filled in creation order, so
-- the loop is first-in first-out; filling one may create later items.
type Cursor = { index ∷ Int, state ∷ State }

next ∷ Env → Cursor → Either Diagnostic (Step Cursor State)
next env cursor = maybe' finished filled
  (Map.lookup cursor.index cursor.state.work)
  where
  finished _ = Right (Done cursor.state)
  filled work = map advanced (run (fillOf work env work) cursor.state)
  advanced copied = Loop { index: cursor.index + 1, state: copied.state }
  fillOf work = if work.function then fillFunction else fillType

values ∷ ∀ v. Map Int v → Array v
values table = map snd (Map.toUnfoldable table ∷ Array (Tuple Int v))

functionIndex ∷ FunctionId → Int
functionIndex (FunctionId index) = index

type Grounds = Map Int (Ty Void)

groundOf ∷ Either Diagnostic Grounds → Work → Either Diagnostic Grounds
groundOf found work = do
  grounds ← found
  arguments ← traverse (groundLowered grounds work.span) work.arguments
  pure
    (Map.insert work.output (TData (TypeId work.declaration) arguments) grounds)

key ∷ Grounds → Work → Either Diagnostic Key
key grounds work = made <$> traverse (groundLowered grounds work.span)
  work.arguments
  where
  made arguments =
    { declaration: work.declaration, function: work.function, arguments }

groundLowered ∷ Grounds → Span → Lowered → Either Diagnostic (Ty Void)
groundLowered grounds span = groundType grounds span <<< loweredType

groundType ∷ Grounds → Span → IR.Ty → Either Diagnostic (Ty Void)
groundType grounds span = case _ of
  IR.TInt → Right TInt
  IR.TBool → Right TBool
  IR.TData (TypeId output) → maybe' missing Right (Map.lookup output grounds)
  arrow@(IR.TFun _ _) → groundSpine (IR.spine arrow)
  where
  missing _ = Left (problemAt (Internal "Invalid type id") span)
  recur part = groundType grounds span part
  groundSpine found = arrows <$> traverse recur found.parameters
    <*> recur found.result
