module Features.Check.Stages (stages, arrowType, openedRow) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal (Open(..))
import Domain.Row (Row(..), openRow)
import Domain.Type (Ty(..), TyRow)
import Features.Check.Scheme (State, Threaded)

-- Declaration stages before its final one are inert quantified rows.
stages ∷ State → Int → TyRow Open → Threaded (Array (TyRow Open))
stages state count row =
  { value:
      map fresh
        (Array.mapWithIndex position (Array.replicate (max 0 (count - 1)) unit))
        <> [ row ]
  , state: state { next = state.next + max 0 (count - 1) }
  }
  where
  position index _ = index
  fresh index = openRow (Hole (state.next + index))

arrowType ∷ Array (Ty Open) → Array (TyRow Open) → Ty Open → Ty Open
arrowType parameters rows result = Array.foldr arrow result
  (Array.zip parameters rows)
  where
  arrow (Tuple parameter row) rest = TFun parameter row rest

openedRow ∷ State → TyRow Open → Threaded (TyRow Open)
openedRow state row@(Row labels tail) = maybe' closed unchanged tail
  where
  closed _ =
    { value: Row labels (Just (Hole state.next))
    , state: state { next = state.next + 1 }
    }
  unchanged _ = { value: row, state }
