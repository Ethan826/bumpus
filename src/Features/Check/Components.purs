module Features.Check.Components (components) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (fromMaybe, maybe')
import Data.Set (Set)
import Data.Set as Set

-- Tarjan's strongly connected components, iterative: the recursion of the
-- textbook algorithm becomes an explicit stack of frames, and every loop
-- is a self tail call, so a chain or a cycle of any length is stack-safe.

-- A pushed list; each push and pop is constant time.
data Stack a = Bottom | Push a (Stack a)

-- A node being explored and the index of its next outgoing edge.
type Frame = { node ∷ Int, edge ∷ Int }

type Search =
  { order ∷ Map Int Int
  , low ∷ Map Int Int
  , open ∷ Set Int
  , stack ∷ Stack Int
  , frames ∷ Stack Frame
  , component ∷ Map Int Int
  , discovered ∷ Int
  , found ∷ Int
  , root ∷ Int
  }

-- `graph !! n` lists node n's successors; the result gives each node its
-- component's index. Components are numbered in the order Tarjan closes
-- them, a reverse topological order; callers compare indices only.
components ∷ Array (Array Int) → Array Int
components graph = Array.mapWithIndex componentOf graph
  where
  done = search graph start
  componentOf node _ = fromMaybe node (Map.lookup node done.component)

start ∷ Search
start =
  { order: Map.empty
  , low: Map.empty
  , open: Set.empty
  , stack: Bottom
  , frames: Bottom
  , component: Map.empty
  , discovered: 0
  , found: 0
  , root: 0
  }

-- With no frame, the next unvisited root starts a depth-first search.
search ∷ Array (Array Int) → Search → Search
search graph state = case state.frames of
  Bottom
    | state.root >= Array.length graph → state
    | Map.member state.root state.order → search graph
        (state { root = state.root + 1 })
    | otherwise → search graph (visit state.root state)
  Push frame rest → search graph (advance graph frame rest state)

visit ∷ Int → Search → Search
visit node state = state
  { order = Map.insert node state.discovered state.order
  , low = Map.insert node state.discovered state.low
  , open = Set.insert node state.open
  , stack = Push node state.stack
  , frames = Push { node, edge: 0 } state.frames
  , discovered = state.discovered + 1
  }

-- Follows the frame's next edge, or finishes its node when none is left.
advance ∷ Array (Array Int) → Frame → Stack Frame → Search → Search
advance graph frame rest state = maybe' finish follow
  (Array.index (fromMaybe [] (Array.index graph frame.node)) frame.edge)
  where
  finish _ = finished frame.node rest (state { frames = rest })
  moved = state { frames = Push (frame { edge = frame.edge + 1 }) rest }
  follow target
    | not (Map.member target state.order) = visit target moved
    | Set.member target state.open = lower frame.node
        (orderOf target state)
        moved
    | otherwise = moved

-- A node whose lowest reachable order is its own roots a component; its
-- parent then inherits its lowest order.
finished ∷ Int → Stack Frame → Search → Search
finished node rest state = case rest of
  Bottom → closed
  Push parent _ → lower parent.node (lowOf node closed) closed
  where
  closed =
    if lowOf node state == orderOf node state then close node state
    else state

-- Pops the stack down to `node`, each popped member into the component.
close ∷ Int → Search → Search
close node state = case state.stack of
  Bottom → state { found = state.found + 1 }
  Push member rest
    | member == node → (assign member rest state)
        { found = state.found + 1 }
    | otherwise → close node (assign member rest state)

assign ∷ Int → Stack Int → Search → Search
assign member rest state = state
  { stack = rest
  , open = Set.delete member state.open
  , component = Map.insert member state.found state.component
  }

lower ∷ Int → Int → Search → Search
lower node value state = state
  { low = Map.insert node (min value (lowOf node state)) state.low }

orderOf ∷ Int → Search → Int
orderOf node state = fromMaybe 0 (Map.lookup node state.order)

lowOf ∷ Int → Search → Int
lowOf node state = fromMaybe 0 (Map.lookup node state.low)
