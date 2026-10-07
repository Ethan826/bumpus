module Features.Resolve.Repeated (repeated) where

import Prelude
import Data.Array as Array
import Data.Maybe (maybe)

type Entry = { name ∷ String, position ∷ Int }
type Marked = { position ∷ Int, repeats ∷ Boolean }

-- Whether each name occurs more than once, by position. Filtering the whole
-- array per name was quadratic, so 20,000 functions spent seconds here
-- (BACKLOG E002); a stable sort puts equal names side by side instead.
repeated ∷ Array String → Array Boolean
repeated names = map repeats (Array.sortWith byPosition marked)
  where
  sorted = Array.sortWith byName (Array.mapWithIndex entry names)
  marked = Array.mapWithIndex (mark sorted) sorted
  entry position text = { name: text, position }
  byName item = item.name
  byPosition item = item.position
  repeats item = item.repeats

mark ∷ Array Entry → Int → Entry → Marked
mark sorted index item =
  { position: item.position
  , repeats: sameAt (index - 1) || sameAt (index + 1)
  }
  where
  sameAt neighbour = maybe false same (Array.index sorted neighbour)
  same other = other.name == item.name
