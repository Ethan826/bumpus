module Features.Specialize.Keys
  ( Env
  , Key
  , Work
  , WorkKind(..)
  , State
  , Counts
  , Specializing
  , specializationLimit
  , enqueue
  , applied
  , arrowOf
  , called
  , ctorAt
  , claim
  , internal
  ) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Resolved
  ( CtorId(..)
  , CtorInfo
  , EffectInfo
  , FunctionId(..)
  , TypeInfo
  )
import Domain.Row (EffectRef)
import Domain.Syntax (Span, problemAt)
import Domain.Type (Ty, TypeId(..))
import Features.Specialize.Copy (Copy, failWith, get, modify)
import Features.Specialize.Intern (Arrows, dataType, internSpine)

-- The checked program's tables and what Specialize computed from them
-- once: the output id of each monomorphic type and function, each
-- constructor's position in its owner, and the type that replaces holes.
type Env =
  { types ∷ Array TypeInfo
  , effects ∷ Array EffectInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array Checked.FunctionDecl
  , monoTypes ∷ Array (Maybe Int)
  , monoFunctions ∷ Array (Maybe Int)
  , positions ∷ Array (Maybe Int)
  , representative ∷ Ty Void
  }

-- A key is hash-consed (R15): a declaration and its ground arguments, each
-- already numbered as an output type or an interned arrow
-- (Features.Specialize.Intern), so comparing two keys costs their arity,
-- never the size of the types they stand for.
type Key = Tuple Int (Array IR.Ty)

-- One output declaration to fill, in creation order, with the span of the
-- reference that created it (a seed's own declaration). An effect's is its
-- user effect's index (FX001 design §4).
type Work =
  { output ∷ Int
  , declaration ∷ Int
  , arguments ∷ Array IR.Ty
  , kind ∷ WorkKind
  , span ∷ Span
  }

data WorkKind = TypeWork | FunctionWork | EffectWork

derive instance eqWorkKind ∷ Eq WorkKind

type Counts =
  { types ∷ Int
  , ctors ∷ Int
  , functions ∷ Int
  , effects ∷ Int
  , work ∷ Int
  , polymorphic ∷ Int
  }

-- Output declarations by output id, the memo tables of polymorphic keys,
-- of effect layouts and of arrows, and the worklist (never emptied: it
-- also records every key in order).
type State =
  { typeKeys ∷ Map Key Int
  , functionKeys ∷ Map Key Int
  , effectKeys ∷ Map (Tuple EffectRef (Array IR.Ty)) Int
  , types ∷ Map Int IR.TypeInfo
  , ctors ∷ Map Int IR.CtorInfo
  , effects ∷ Map Int IR.EffectInfo
  , functions ∷ Map Int IR.FunctionDecl
  , work ∷ Map Int Work
  , arrows ∷ Arrows
  , counts ∷ Counts
  }

type Specializing = Copy State

-- Design §6: a resource guard over keys of polymorphic declarations only;
-- an effect's key counts when it has type arguments (FX001 design §4).
specializationLimit ∷ Int
specializationLimit = 10000

enqueue ∷ Work → State → State
enqueue item state = state
  { work = Map.insert state.counts.work item state.work
  , counts = state.counts { work = state.counts.work + 1 }
  }

-- The output type of a declared type at ground arguments, created on
-- first reference at `span`.
applied ∷ Env → Span → TypeId → Array IR.Ty → Specializing IR.Ty
applied env span (TypeId declaration) arguments
  | Array.null arguments = maybe' (internal "Invalid type id" span)
      (pure <<< dataType)
      (join (Array.index env.monoTypes declaration))
  | otherwise = get >>= remembered
      where
      key = Tuple declaration arguments
      remembered state = maybe' (newType env span key)
        (pure <<< dataType)
        (Map.lookup key state.typeKeys)

-- The arrow of `parameters` to `result`, every suffix interned once.
arrowOf ∷ Array IR.Ty → IR.Ty → Specializing IR.Ty
arrowOf parameters result = do
  state ← get
  let spun = internSpine parameters result state.arrows
  modify (withArrows spun.arrows)
  pure spun.ty
  where
  withArrows arrows state = state { arrows = arrows }

-- The output function for a call at ground arguments.
called ∷ Env → Span → FunctionId → Array IR.Ty → Specializing FunctionId
called env span (FunctionId declaration) arguments
  | Array.null arguments = maybe' (internal "Invalid function id" span)
      (pure <<< FunctionId)
      (join (Array.index env.monoFunctions declaration))
  | otherwise = get >>= remembered
      where
      key = Tuple declaration arguments
      remembered state = maybe' (newFunction span key)
        (pure <<< FunctionId)
        (Map.lookup key state.functionKeys)

-- The output constructor of `id` in the output type `owner`.
ctorAt ∷ Env → Span → IR.Ty → CtorId → Specializing CtorId
ctorAt env span owner (CtorId id) = do
  state ← get
  maybe' (internal "Invalid constructor id" span) pure
    (outputCtor state owner =<< join (Array.index env.positions id))

internal ∷ ∀ a b. String → Span → a → Specializing b
internal text span _ = failWith (problemAt (Internal text) span)

outputCtor ∷ State → IR.Ty → Int → Maybe CtorId
outputCtor state owner position = case owner of
  IR.TData (TypeId output) → Map.lookup output state.types >>= at
  _ → Nothing
  where
  at info = Array.index info.ctors position

-- A type key takes the next output id and a block of constructor ids, one
-- per declared constructor in order; its fields are filled when its work
-- item is reached.
newType ∷ Env → Span → Key → Unit → Specializing IR.Ty
newType env span key@(Tuple declaration arguments) _ = do
  claim span
  info ← maybe' (internal "Invalid type id" span) pure
    (Array.index env.types declaration)
  modify (created info)
  state ← get
  pure (dataType (state.counts.types - 1))
  where
  created info state = enqueue
    { output: state.counts.types
    , declaration
    , arguments
    , kind: TypeWork
    , span
    }
    state
      { typeKeys = Map.insert key state.counts.types state.typeKeys
      , types = Map.insert state.counts.types (output info state) state.types
      , counts = state.counts
          { types = state.counts.types + 1
          , ctors = state.counts.ctors + Array.length info.ctors
          }
      }
  output info state =
    { name: info.name
    , arguments
    , ctors: Array.mapWithIndex (offset state.counts.ctors) info.ctors
    , span: info.span
    }
  offset base index _ = CtorId (base + index)

newFunction ∷ Span → Key → Unit → Specializing FunctionId
newFunction span key@(Tuple declaration arguments) _ = do
  claim span
  modify created
  state ← get
  pure (FunctionId (state.counts.functions - 1))
  where
  created state = enqueue
    { output: state.counts.functions
    , declaration
    , arguments
    , kind: FunctionWork
    , span
    }
    state
      { functionKeys = Map.insert key state.counts.functions
          state.functionKeys
      , counts = state.counts { functions = state.counts.functions + 1 }
      }

-- Counts one more polymorphic key, failing at the reference that would
-- create key `specializationLimit + 1`.
claim ∷ Span → Specializing Unit
claim span = do
  state ← get
  if state.counts.polymorphic >= specializationLimit then
    failWith (problemAt (SpecializationLimit specializationLimit) span)
  else modify counted
  where
  counted state = state
    { counts = state.counts { polymorphic = state.counts.polymorphic + 1 } }
