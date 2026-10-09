module Features.Check.Inhabited (inhabitation) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Array.NonEmpty as NonEmpty
import Data.Either (Either(..))
import Data.Foldable (and, traverse_)
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (traverse)
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeId(..), TypeInfo)
import Features.Check.Tables (Lookup, ctorInfo, typeInfo)

-- `value` depends on `key`; both are dense table indices.
type Edge = { key ∷ Int, value ∷ Int }

-- Built once: the constructors with a field of each type, the types that
-- list each constructor, and each constructor's data-typed fields.
type Graph =
  { users ∷ Array (Array Int)
  , owners ∷ Array (Array Int)
  , needs ∷ Array (Array Int)
  }

-- `frontier` holds the constructors first found inhabited last round.
type Round =
  { ctors ∷ Array Boolean, types ∷ Array Boolean, frontier ∷ Array Int }

-- Marks the end of an index group; never a table index.
noValue ∷ Int
noValue = -1

-- Array.modifyAtIndices nests one ST bind per index and overflowed the stack
-- between 6,000 and 8,000 indices (20,000 one-constructor types inhabit in
-- one round), so flags are set this many at a time.
markChunk ∷ Int
markChunk = 1024

-- The least fixed point: a constructor is inhabited when every field type
-- is, and a type when any constructor it lists is. Recomputing every
-- constructor per pass took one pass per link of a type chain, recursing
-- once per pass, so 3,000 chained types overflowed the stack (G001 final
-- review I2). This worklist revisits only the users of newly inhabited
-- types, in a tailRecM loop of one round per link. Each round still copies
-- the two flag arrays: O(edges·log edges + rounds·(types + constructors)).
-- The lookups of the old first pass run first, so a bad id fails the same.
inhabitation ∷ Array TypeInfo → Array CtorInfo → Lookup (Array Boolean)
inhabitation types ctors = do
  traverse_ (validate types ctors) ctors
  tailRecM (settle graph) (start graph)
  where
  graph = dependencies types ctors

validate ∷ Array TypeInfo → Array CtorInfo → CtorInfo → Lookup Unit
validate types ctors ctor = traverse_ field ctor.fields
  where
  field = case _ of
    TData id _ _ → typeInfo types id >>= listed
    _ → pure unit
  listed info = traverse_ (ctorInfo ctors) info.ctors

dependencies ∷ Array TypeInfo → Array CtorInfo → Graph
dependencies types ctors =
  { users: grouped (Array.length types) (edgesOf useEdges ctors)
  , owners: grouped (Array.length ctors) (edgesOf ownEdges types)
  , needs: map dataFields ctors
  }
  where
  useEdges index ctor = map (edgeTo index) (dataFields ctor)
  ownEdges index info = map (edgeTo index <<< ctorIndex) info.ctors
  edgeTo value key = { key, value }
  ctorIndex (CtorId index) = index

edgesOf ∷ ∀ a. (Int → a → Array Edge) → Array a → Array Edge
edgesOf edges = Array.concat <<< Array.mapWithIndex edges

-- One group per key in 0..count-1, empty groups included: a marker edge
-- per key keeps every key present after grouping.
grouped ∷ Int → Array Edge → Array (Array Int)
grouped count edges = map members
  (Array.groupAllBy byKey (Array.filter inRange edges <> markers))
  where
  inRange edge = edge.key >= 0 && edge.key < count
  markers = Array.mapWithIndex marker (Array.replicate count unit)
  marker key _ = { key, value: noValue }
  byKey left right = compare left.key right.key
  members = Array.mapMaybe present <<< NonEmpty.toArray
  present edge = if edge.value == noValue then Nothing else Just edge.value

-- Every arrow is inhabited (a diverging function exists at every type,
-- FN001 design §3), so like Int it is no constructor's need.
dataFields ∷ CtorInfo → Array Int
dataFields ctor = Array.mapMaybe dataIndex ctor.fields
  where
  dataIndex = case _ of
    TData (TypeId index) _ _ → Just index
    _ → Nothing

start ∷ Graph → Round
start graph =
  { ctors: Array.replicate (Array.length graph.needs) false
  , types: Array.replicate (Array.length graph.users) false
  , frontier: Array.concat (Array.mapWithIndex nullary graph.needs)
  }
  where
  nullary index need = if Array.null need then [ index ] else []

settle ∷ Graph → Round → Lookup (Step Round (Array Boolean))
settle graph round =
  if Array.null round.frontier then pure (Done round.ctors)
  else Loop <$> advance graph round

advance ∷ Graph → Round → Lookup Round
advance graph round = do
  owners ← Array.concat <$> traverse (at graph.owners) round.frontier
  fresh ← Array.filterA unflagged (Array.nub owners)
  let types = marked fresh round.types
  users ← Array.concat <$> traverse (at graph.users) fresh
  frontier ← Array.filterA (ready graph types ctors) (Array.nub users)
  pure { ctors, types, frontier }
  where
  ctors = marked round.frontier round.ctors
  unflagged index = not <$> at round.types index

ready ∷ Graph → Array Boolean → Array Boolean → Int → Lookup Boolean
ready graph types ctors index = do
  done ← at ctors index
  if done then pure false
  else at graph.needs index >>= map and <<< traverse (at types)

-- Sets the flags at `indices`, one chunk of them per array copy.
marked ∷ Array Int → Array Boolean → Array Boolean
marked indices flags =
  if Array.null indices then flags else Array.foldl mark flags starts
  where
  lastChunk = (Array.length indices - 1) / markChunk
  starts = map (markChunk * _) (Array.range 0 lastChunk)
  mark current offset = Array.modifyAtIndices
    (Array.slice offset (offset + markChunk) indices)
    (const true)
    current

-- Indices come from tables of matching length, so a miss is a bug.
at ∷ ∀ a. Array a → Int → Lookup a
at items index = maybe' missing Right (Array.index items index)
  where
  missing _ = Left (Internal "Inhabitation index out of range")
