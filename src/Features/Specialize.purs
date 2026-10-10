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
import Domain.Row (Label(..), closedRow)
import Domain.Syntax (Diagnostic, Span, origin, problemAt)
import Domain.Type (Ty(..), TypeId(..))
import Domain.Type.Parts (arrows)
import Features.Specialize.Body (fillFunction)
import Features.Specialize.Copy (run)
import Features.Specialize.Intern (funTypes)
import Features.Specialize.Keys (Env, State, Work, WorkKind(..))
import Features.Specialize.Lower (fillEffect, fillType)
import Features.Specialize.Seeds (environment, seeded)

-- A key as tests see it: the checked declaration's id and its ground type
-- arguments (empty for a monomorphic declaration). An effect key's
-- declaration is its user effect's (FX001 design §4).
type Key =
  { declaration ∷ Int
  , function ∷ Boolean
  , effect ∷ Boolean
  , arguments ∷ Array (Ty Void)
  }

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
        , effects: values finished.state.effects
        , functions: values finished.state.functions
        , funTypes: funTypes finished.state.arrows
        , entry: finished.entry
        }
    )

-- Every key, types, then user effects, then functions, each in output-id
-- order. A key's arguments name only earlier output types and layouts, so
-- one pass rebuilds them; an arrow is rebuilt along its spine through the
-- table by a loop. This rebuilds whole types, for tests only; keys
-- themselves are numbers.
specializationKeys ∷ Checked.Program → Either Diagnostic (Array Key)
specializationKeys checked = do
  finished ← specialized TInt checked
  let made = values finished.state.work
  let types = Array.filter (kindIs TypeWork) made
  let table = funTypes finished.state.arrows
  let effects = finished.state.effects
  typesSoFar ← foldl (groundOf { table, effects }) (Right Map.empty) types
  traverse (key { types: typesSoFar, table, effects })
    ( types <> Array.filter (kindIs EffectWork) made
        <> Array.filter (kindIs FunctionWork) made
    )
  where
  kindIs kind work = work.kind == kind

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
  fillOf work = case work.kind of
    TypeWork → fillType
    FunctionWork → fillFunction
    EffectWork → fillEffect

values ∷ ∀ v. Map Int v → Array v
values table = map snd (Map.toUnfoldable table ∷ Array (Tuple Int v))

functionIndex ∷ FunctionId → Int
functionIndex (FunctionId index) = index

-- The ground type of each output type so far, the arrow table and the
-- effect layouts. Keys hold no rows: specialization erases them.
type Grounds =
  { types ∷ Map Int (Ty Void)
  , table ∷ Array IR.FunType
  , effects ∷ Map Int IR.EffectInfo
  }

type Tables = { table ∷ Array IR.FunType, effects ∷ Map Int IR.EffectInfo }

groundOf
  ∷ Tables
  → Either Diagnostic (Map Int (Ty Void))
  → Work
  → Either Diagnostic (Map Int (Ty Void))
groundOf tables found work = do
  types ← found
  arguments ← traverse
    ( groundType { types, table: tables.table, effects: tables.effects }
        work.span
    )
    work.arguments
  pure (Map.insert work.output (rowless arguments) types)
  where
  -- Rows are erased in specialization (FX001 design §4).
  rowless arguments = TData (TypeId work.declaration) arguments []

key ∷ Grounds → Work → Either Diagnostic Key
key grounds work = made <$> traverse (groundType grounds work.span)
  work.arguments
  where
  made arguments =
    { declaration: work.declaration
    , function: work.kind == FunctionWork
    , effect: work.kind == EffectWork
    , arguments
    }

groundType ∷ Grounds → Span → IR.Ty → Either Diagnostic (Ty Void)
groundType grounds span = case _ of
  IR.TInt → Right TInt
  IR.TBool → Right TBool
  IR.TUnit → Right TUnit
  IR.TData (TypeId output) → maybe' missing Right
    (Map.lookup output grounds.types)
  arrow@(IR.TFun _) → groundSpine (IR.spine grounds.table arrow)
  IR.THandler (IR.EffectKey output) → maybe' missingEffect groundHandler
    (Map.lookup output grounds.effects)
  where
  missing _ = Left (problemAt (Internal "Invalid type id") span)
  missingEffect _ = Left (problemAt (Internal "Invalid effect key") span)
  groundHandler info = handlerOf info <$> traverse recur info.arguments
  handlerOf info arguments = THandler (Label info.effect arguments) closedRow
  recur part = groundType grounds span part
  groundSpine found = arrows <$> traverse recur found.parameters
    <*> recur found.result
