module Format.Go.Layout
  ( Member
  , Declared
  , Layout
  , layout
  , tagOf
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (fromMaybe)
import Domain.IR.Internal (CtorInfo, Tables, TypeInfo)
import Domain.Resolved (CtorId(..), TypeId(..))

-- A constructor with its 1-based position in its owner's declaration.
type Member = { id ∷ CtorId, tag ∷ Int, ctor ∷ CtorInfo }

-- A declared type with its constructors in declaration order.
type Declared = { id ∷ TypeId, members ∷ Array Member }

-- Built once per program so no emitter searches the tables: scanning every
-- type for each constructor made 10,000 types take 5.6 s to emit (A003
-- final review I3). `tags` is indexed by CtorId.
type Layout = { tags ∷ Array Int, types ∷ Array Declared }

type Slot = { id ∷ CtorId, tag ∷ Int, position ∷ Int }

type Placed = { member ∷ Member, position ∷ Int }

type Range = { first ∷ Int, count ∷ Int }

-- Slots enumerate every type's constructors in declaration order. Sorting
-- them by id aligns them with the constructor table, which joins each with
-- its CtorInfo without a lookup; sorting back by position regroups them.
layout ∷ Tables → Layout
layout tables =
  { tags: map memberTag joined
  , types: Array.mapWithIndex (declared ordered) (ranges tables.types)
  }
  where
  slots = Array.mapWithIndex positioned
    (Array.concatMap ranked tables.types)
  positioned position slot = { id: slot.id, tag: slot.tag, position }
  joined = Array.zipWith place (Array.sortWith slotIndex slots) tables.ctors
  ordered = map placedMember (Array.sortWith placedPosition joined)
  memberTag placed = placed.member.tag
  placedMember placed = placed.member
  placedPosition placed = placed.position

-- Tags are 1-based, so the 0 fallback never names a constructor; checked
-- programs only mention declared constructors, which all have tags.
tagOf ∷ Layout → CtorId → Int
tagOf program (CtorId index) = fromMaybe 0 (Array.index program.tags index)

ranked ∷ TypeInfo → Array { id ∷ CtorId, tag ∷ Int }
ranked info = Array.mapWithIndex rank info.ctors
  where
  rank index id = { id, tag: index + 1 }

slotIndex ∷ Slot → Int
slotIndex slot = ctorIndex slot.id
  where
  ctorIndex (CtorId index) = index

place ∷ Slot → CtorInfo → Placed
place slot ctor =
  { member: { id: slot.id, tag: slot.tag, ctor }, position: slot.position }

-- Each type's slice of the regrouped constructors.
declared ∷ Array Member → Int → Range → Declared
declared ordered index range =
  { id: TypeId index
  , members: Array.slice range.first (range.first + range.count) ordered
  }

ranges ∷ Array TypeInfo → Array Range
ranges types = Array.zipWith range (Array.scanl add 0 counts) counts
  where
  counts = map ctorCount types
  ctorCount info = Array.length info.ctors
  range total count = { first: total - count, count }
