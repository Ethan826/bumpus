module Format.Go.Lowered
  ( Scope
  , Shape
  , Wrapper
  , EffectShape
  , Lowered
  , Lowering
  , Several
  , shapeOf
  , functionWrapper
  , ctorWrapper
  , operationWrapper
  , effectShape
  , leaf
  , variable
  , both
  , several
  ) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe, maybe)
import Data.Traversable (mapAccumL)
import Data.Tuple (Tuple(..))
import Domain.IR.Internal as IR
import Domain.IR.Internal
  ( CtorInfo
  , EffectKey(..)
  , FunType
  , FunTypeId(..)
  , Ty(..)
  )
import Domain.Resolved (CtorId(..), FunctionId(..), LocalId)
import Format.Go.Capture (Free, none, read, union)
import Format.Go.Cleanup (usesDefects)
import Format.Go.Context (effectKey, usesContext)
import Format.Go.Data (ctorName, functionName, performName)
import Format.Go.Layout (Layout)

-- What lowering reads about the whole program (FN001): each function's and
-- constructor's signature by id, for arity and staged wrappers, and the
-- interned arrows, as a table and by (parameter, result), so a stage's Go
-- type is found by number, never by spelling a type (design §13 rule 8).
-- `context` is the program's mode (Format.Go.Context) and `effects` holds
-- each effect layout's runtime key and operations, by EffectKey. `defects`
-- is whether `defer` or `crash` occurs (Format.Go.Cleanup); the report
-- names a payload type by `types` and `effectInfos`.
type Shape =
  { signatures ∷ Array Wrapper
  , ctors ∷ Array Wrapper
  , funTypes ∷ Array FunType
  , arrows ∷ Map (Tuple Ty Ty) FunTypeId
  , context ∷ Boolean
  , defects ∷ Boolean
  , effects ∷ Array EffectShape
  , types ∷ Array IR.TypeInfo
  , effectInfos ∷ Array IR.EffectInfo
  }

-- An effect layout: its runtime key, and each operation as the n-ary
-- perform function `waxwingEff{N}Op{k}` (Format.Go.Effect).
type EffectShape = { key ∷ Int, operations ∷ Array Wrapper }

-- What lowering one function body reads: the layout, the program's shape,
-- and the function whose matches, lambdas, pipes and application helpers
-- are being numbered and lifted (E005).
type Scope = { tables ∷ Layout, owner ∷ FunctionId, shape ∷ Shape }

-- An n-ary Go function `name` that some value stages (design §13 rules 3
-- and 5): its staged wrapper is `nameValue`, `nameStage<k>`, `nameEntry`.
type Wrapper = { name ∷ String, parameters ∷ Array Ty, result ∷ Ty }

-- One expression's Go code, the number the next lifted function of its
-- owner will take, the top-level functions it lifted (in the pre-order of
-- their numbers), its free locals (Format.Go.Capture) and the staged
-- wrappers its values need (emitted once each, Format.Go).
type Lowered =
  { code ∷ String
  , next ∷ Int
  , lifted ∷ Array String
  , free ∷ Free
  , wrappers ∷ Array Wrapper
  }

-- Lowers an expression whose first lifted function (if any) takes the
-- given number.
type Lowering = Int → IR.Expr → Lowered

type Several =
  { codes ∷ Array String
  , next ∷ Int
  , lifted ∷ Array String
  , frees ∷ Array Free
  , wrappers ∷ Array Wrapper
  }

shapeOf ∷ IR.Program → Shape
shapeOf program'@(IR.Program program) =
  { signatures: map signature program.functions
  , ctors: Array.mapWithIndex constructor program.ctors
  , funTypes: program.funTypes
  , arrows: Map.fromFoldable (Array.mapWithIndex numbered program.funTypes)
  , context: usesContext program'
  , defects: usesDefects program'
  , effects: Array.mapWithIndex layout program.effects
  , types: program.types
  , effectInfos: program.effects
  }
  where
  signature definition =
    { name: functionName definition.id
    , parameters: definition.parameters
    , result: definition.result
    }
  numbered index arrow =
    Tuple (Tuple arrow.parameter arrow.result) (FunTypeId index)
  layout index info =
    { key: effectKey info.effect
    , operations: Array.mapWithIndex (operation index) info.operations
    }
  operation index position info =
    { name: performName (EffectKey index) position
    , parameters: info.parameters
    , result: info.result
    }

-- Output ids index the tables. A missing id (a compiler bug) reads as a
-- nullary signature, so its uses lower as calls, as before FN001.
functionWrapper ∷ Shape → FunctionId → Wrapper
functionWrapper shape id@(FunctionId index) =
  maybe (missing (functionName id)) identity
    (Array.index shape.signatures index)

ctorWrapper ∷ Shape → CtorId → Wrapper
ctorWrapper shape id@(CtorId index) =
  maybe (missing (ctorName id)) identity (Array.index shape.ctors index)

-- A missing layout is a compiler bug; each caller decides how it shows.
effectShape ∷ Shape → EffectKey → Maybe EffectShape
effectShape shape (EffectKey index) = Array.index shape.effects index

operationWrapper ∷ Shape → EffectKey → Int → Wrapper
operationWrapper shape key position =
  maybe (missing (performName key position)) identity
    (effectShape shape key >>= operationAt position)
  where
  operationAt index layout = Array.index layout.operations index

-- Code that contains no lifted function and reads no local.
leaf ∷ Int → String → Lowered
leaf next code = { code, next, lifted: [], free: none, wrappers: [] }

variable ∷ Int → String → LocalId → Ty → Lowered
variable next code id ty =
  { code, next, lifted: [], free: read id ty, wrappers: [] }

-- Two operands, left first, joined by `render`.
both
  ∷ Lowering
  → Int
  → (String → String → String)
  → IR.Expr
  → IR.Expr
  → Lowered
both lower next render left right =
  { code: render first.code second.code
  , next: second.next
  , lifted: first.lifted <> second.lifted
  , free: union [ first.free, second.free ]
  , wrappers: first.wrappers <> second.wrappers
  }
  where
  first = lower next left
  second = lower first.next right

-- Left to right, so lifted functions are numbered in source pre-order.
-- mapAccumL traverses an Array in balanced halves, so long argument lists
-- are safe.
several ∷ Lowering → Int → Array IR.Expr → Several
several lower next expressions =
  { codes: map codeOf threaded.value
  , next: threaded.accum
  , lifted: Array.concatMap liftedOf threaded.value
  , frees: map freeOf threaded.value
  , wrappers: Array.concatMap wrappersOf threaded.value
  }
  where
  threaded = mapAccumL step next expressions
  step counter expression = advanced (lower counter expression)
  advanced result = { accum: result.next, value: result }
  codeOf result = result.code
  liftedOf result = result.lifted
  freeOf result = result.free
  wrappersOf result = result.wrappers

missing ∷ String → Wrapper
missing name = { name, parameters: [], result: TInt }

constructor ∷ Int → CtorInfo → Wrapper
constructor index ctor =
  { name: ctorName (CtorId index)
  , parameters: ctor.fields
  , result: TData ctor.owner
  }
