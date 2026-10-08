module Features.Check.Components (components) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), isJust, maybe')
import Data.Set (Set)
import Data.Set as Set
import Data.Traversable (sequence)
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, origin, problemAt)

-- Tarjan's strongly connected components, iterative: the recursion of the
-- textbook algorithm becomes an explicit stack of frames, and every loop
-- is a self tail call, so a chain or a cycle of any length is stack-safe.
-- A node's discovery order and lowest reachable order live in its frame,
-- and an open node's order in `open`, so neither is ever looked up and
-- missed. What would still be a compiler bug (an edge to a node the graph
-- lacks, a component root gone from the stack, a node left unnumbered)
-- stops the search with E_INTERNAL instead of a wrong partition.

-- A pushed list; each push and pop is constant time.
data Stack a = Bottom | Push a (Stack a)

-- A node being explored, its successors and the index of the next one,
-- its discovery order, and the lowest order reached from it so far.
type Frame =
  { node ∷ Int, successors ∷ Array Int, edge ∷ Int, order ∷ Int, low ∷ Int }

-- `open` maps each node on the component stack to its discovery order.
type Search =
  { seen ∷ Set Int
  , open ∷ Map Int Int
  , stack ∷ Stack Int
  , frames ∷ Stack Frame
  , component ∷ Map Int Int
  , discovered ∷ Int
  , found ∷ Int
  , root ∷ Int
  , fault ∷ Maybe String
  }

-- `graph !! n` lists node n's successors; the result gives each node its
-- component's index. Components are numbered in the order Tarjan closes
-- them, a reverse topological order; callers compare indices only.
components ∷ Array (Array Int) → Either Diagnostic (Array Int)
components graph = maybe' numbered internal done.fault
  where
  done = search graph start
  numbered _ = sequence (Array.mapWithIndex componentOf graph)
  componentOf node _ = maybe' unnumbered Right
    (Map.lookup node done.component)
  unnumbered _ = internal "Node outside every component"

start ∷ Search
start =
  { seen: Set.empty
  , open: Map.empty
  , stack: Bottom
  , frames: Bottom
  , component: Map.empty
  , discovered: 0
  , found: 0
  , root: 0
  , fault: Nothing
  }

-- With no frame, the next unvisited root starts a depth-first search.
search ∷ Array (Array Int) → Search → Search
search graph state = case state.frames of
  _ | isJust state.fault → state
  Bottom
    | state.root >= Array.length graph → state
    | Set.member state.root state.seen → search graph
        (state { root = state.root + 1 })
    | otherwise → search graph (visit graph state.root state)
  Push frame rest → search graph (advance graph frame rest state)

-- A node outside the graph has no successors to read: a compiler bug.
visit ∷ Array (Array Int) → Int → Search → Search
visit graph node state = maybe' missing enter (Array.index graph node)
  where
  missing _ = failed "Edge to a node outside the graph" state
  enter successors = state
    { seen = Set.insert node state.seen
    , open = Map.insert node state.discovered state.open
    , stack = Push node state.stack
    , frames = Push
        { node
        , successors
        , edge: 0
        , order: state.discovered
        , low: state.discovered
        }
        state.frames
    , discovered = state.discovered + 1
    }

-- Follows the frame's next edge, or finishes its node when none is left.
-- An edge to an open node lowers the frame's low to that node's order.
advance ∷ Array (Array Int) → Frame → Stack Frame → Search → Search
advance graph frame rest state = maybe' finish follow
  (Array.index frame.successors frame.edge)
  where
  finish _ = finished frame rest (state { frames = rest })
  next = frame { edge = frame.edge + 1 }
  moved = state { frames = Push next rest }
  follow target
    | not (Set.member target state.seen) = visit graph target moved
    | otherwise = maybe' unchanged lowered (Map.lookup target state.open)
  unchanged _ = moved
  lowered order = state
    { frames = Push (next { low = min next.low order }) rest }

-- A node whose lowest reachable order is its own roots a component; its
-- parent then inherits its lowest order.
finished ∷ Frame → Stack Frame → Search → Search
finished frame rest state = case rest of
  Bottom → closed
  Push parent more → closed
    { frames = Push (parent { low = min parent.low frame.low }) more }
  where
  closed =
    if frame.low == frame.order then close frame.node state
    else state

-- Pops the stack down to `node`, each popped member into the component.
close ∷ Int → Search → Search
close node state = case state.stack of
  Bottom → failed "Component root missing from the stack" state
  Push member rest
    | member == node → (assign member rest state)
        { found = state.found + 1 }
    | otherwise → close node (assign member rest state)

assign ∷ Int → Stack Int → Search → Search
assign member rest state = state
  { stack = rest
  , open = Map.delete member state.open
  , component = Map.insert member state.found state.component
  }

failed ∷ String → Search → Search
failed text state = state { fault = Just text }

internal ∷ ∀ a. String → Either Diagnostic a
internal text = Left
  (problemAt (Internal text) { start: origin, end: origin })
