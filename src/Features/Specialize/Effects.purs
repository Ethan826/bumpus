module Features.Specialize.Effects (effectAt) where

import Prelude
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Tuple (Tuple(..))
import Domain.IR.Internal as IR
import Domain.Ids (EffectId(..))
import Domain.Row (EffectRef(..))
import Domain.Syntax (Span)
import Features.Specialize.Copy (get, modify)
import Features.Specialize.Keys
  ( Env
  , Specializing
  , WorkKind(..)
  , claim
  , enqueue
  , internal
  )

type EffectKey = Tuple EffectRef (Array IR.Ty)

-- The layout of `effect` at ground `arguments` (FX001 design §4), created
-- on first reference at `span`. Effects have no monomorphic seeds: a
-- layout exists only once a handler type, a handler or an operation needs
-- it. A user effect's work item fills its operations' types
-- (Features.Specialize.Lower.fillEffect), whose own keys it thereby
-- reaches; Console's and Fail's layouts occur only as handler types and
-- have no operations.
effectAt
  ∷ Env → Span → EffectRef → Array IR.Ty → Specializing IR.EffectKey
effectAt env span effect arguments = get >>= remembered
  where
  key = Tuple effect arguments
  remembered state = maybe' (newEffect env span key)
    (pure <<< IR.EffectKey)
    (Map.lookup key state.effectKeys)

-- A key with type arguments counts toward the specialization limit, as a
-- polymorphic type's does.
newEffect ∷ Env → Span → EffectKey → Unit → Specializing IR.EffectKey
newEffect env span key@(Tuple effect arguments) _ = do
  unless (Array.null arguments) (claim span)
  name ← nameOf env span effect
  modify (created name)
  state ← get
  pure (IR.EffectKey (state.counts.effects - 1))
  where
  created name state = withEntry name (enqueued state)
  withEntry name state = state
    { effectKeys = Map.insert key state.counts.effects state.effectKeys
    , effects = Map.insert state.counts.effects
        { effect, name, arguments, operations: [], span }
        state.effects
    , counts = state.counts { effects = state.counts.effects + 1 }
    }
  enqueued state = case effect of
    UserEffect id → enqueue (work state id) state
    _ → state
  work state (EffectId declaration) =
    { output: state.counts.effects
    , declaration
    , arguments
    , kind: EffectWork
    , span
    }

nameOf ∷ Env → Span → EffectRef → Specializing String
nameOf env span = case _ of
  UserEffect (EffectId index) → maybe' (internal "Invalid effect id" span)
    (pure <<< effectName)
    (Array.index env.effects index)
  ConsoleEffect → pure "Console"
  FailEffect → pure "Fail"
  where
  effectName info = info.name
