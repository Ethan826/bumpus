module Features.Specialize.Intern
  ( Interned(..)
  , Lowered
  , Arrows
  , Spun
  , noArrows
  , int
  , bool
  , dataType
  , keyOf
  , loweredType
  , internSpine
  ) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Tuple (Tuple(..))
import Domain.IR.Internal as IR
import Domain.Type (TypeId(..))

-- A ground type as a part of a specialization key: Int, Bool, an output
-- type's number, or an interned arrow's number. Comparing two costs
-- constant time whatever the types they stand for (ruling R15, FN001
-- Task 5).
data Interned = KInt | KBool | KData Int | KFun Int

derive instance eqInterned ∷ Eq Interned
derive instance ordInterned ∷ Ord Interned

-- A lowered type beside its number, computed together, so no key is ever
-- found by walking or spelling a type.
type Lowered = { ty ∷ IR.Ty, key ∷ Interned }

-- Arrows are hash-consed: each (parameter, result) pair of numbers gets
-- one number, in creation order. A spine's suffixes are numbered from its
-- final result outwards, so every suffix of every arrow is numbered once,
-- and design §13 rule 8 can name one Go type per number (Task 6).
type Arrows = { numbers ∷ Map (Tuple Interned Interned) Int, count ∷ Int }

type Spun = { arrows ∷ Arrows, lowered ∷ Lowered }

noArrows ∷ Arrows
noArrows = { numbers: Map.empty, count: 0 }

int ∷ Lowered
int = { ty: IR.TInt, key: KInt }

bool ∷ Lowered
bool = { ty: IR.TBool, key: KBool }

-- The output type numbered `output`.
dataType ∷ Int → Lowered
dataType output = { ty: IR.TData (TypeId output), key: KData output }

keyOf ∷ Lowered → Interned
keyOf lowered = lowered.key

loweredType ∷ Lowered → IR.Ty
loweredType lowered = lowered.ty

-- The arrow of `parameters` to `result`, each already lowered and
-- numbered. Array.foldr is a loop, so a spine of any length costs one
-- table lookup per arrow and no stack.
internSpine ∷ Array Lowered → Lowered → Arrows → Spun
internSpine parameters result arrows =
  Array.foldr arrow { arrows, lowered: result } parameters

arrow ∷ Lowered → Spun → Spun
arrow parameter spun = maybe' fresh found
  (Map.lookup pair spun.arrows.numbers)
  where
  pair = Tuple parameter.key spun.lowered.key
  ty = IR.TFun parameter.ty spun.lowered.ty
  found number = { arrows: spun.arrows, lowered: { ty, key: KFun number } }
  fresh _ =
    { arrows:
        { numbers: Map.insert pair spun.arrows.count spun.arrows.numbers
        , count: spun.arrows.count + 1
        }
    , lowered: { ty, key: KFun spun.arrows.count }
    }
