module Features.Specialize.Intern
  ( Arrows
  , Spun
  , noArrows
  , dataType
  , funTypes
  , internSpine
  ) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Tuple (Tuple(..), snd)
import Domain.IR.Internal as IR
import Domain.Type (TypeId(..))

-- Arrows are hash-consed (FN001 Task 5, like ruling R15's applications):
-- each (parameter, result) pair gets one IR.FunTypeId, in creation order.
-- Both parts are already numbers or builtins, so a lookup compares in
-- constant time. A spine's suffixes are numbered from its final result
-- outwards, so every suffix of every arrow is numbered once, after its
-- result and parameter, and Go names one type per number (design §13
-- rule 8). `entries` is the IR's `funTypes` table by number.
type Arrows =
  { numbers ∷ Map (Tuple IR.Ty IR.Ty) Int
  , entries ∷ Map Int IR.FunType
  , count ∷ Int
  }

type Spun = { arrows ∷ Arrows, ty ∷ IR.Ty }

noArrows ∷ Arrows
noArrows = { numbers: Map.empty, entries: Map.empty, count: 0 }

-- The output type numbered `output`.
dataType ∷ Int → IR.Ty
dataType output = IR.TData (TypeId output)

-- The table in number order.
funTypes ∷ Arrows → Array IR.FunType
funTypes arrows = map snd
  (Map.toUnfoldable arrows.entries ∷ Array (Tuple Int IR.FunType))

-- The arrow of `parameters` to `result`, each already lowered. Array.foldr
-- is a loop, so a spine of any length costs one table lookup per arrow and
-- no stack.
internSpine ∷ Array IR.Ty → IR.Ty → Arrows → Spun
internSpine parameters result arrows =
  Array.foldr arrow { arrows, ty: result } parameters

arrow ∷ IR.Ty → Spun → Spun
arrow parameter spun = maybe' fresh found
  (Map.lookup pair spun.arrows.numbers)
  where
  pair = Tuple parameter spun.ty
  found number = spun { ty = numbered number }
  fresh _ =
    { arrows:
        { numbers: Map.insert pair spun.arrows.count spun.arrows.numbers
        , entries: Map.insert spun.arrows.count
            { parameter, result: spun.ty }
            spun.arrows.entries
        , count: spun.arrows.count + 1
        }
    , ty: numbered spun.arrows.count
    }
  numbered number = IR.TFun (IR.FunTypeId number)
