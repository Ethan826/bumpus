-- A staged wrapper's entry (FN001 design §13 rule 4). The last stage
-- passes the whole chain; the entry walks it once, from the last argument
-- to the first, storing each node's value into one array per distinct
-- argument type, chosen by package-level kind and slot tables, then makes
-- one n-ary call of the function. A position's node type is asserted from
-- its kind, so a chain built by the wrapper's own stages always fits.
module Format.Go.Entry (entry, nodeName) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.String.Common (joinWith)
import Data.Traversable (mapAccumL)
import Data.Tuple (Tuple(..))
import Domain.IR.Internal (Ty)
import Format.Go.Data (goType)

-- Where one argument lands: its type's index among the function's
-- distinct argument types, and its index among that type's arguments.
type Placed = { kind ∷ Int, slot ∷ Int }

nodeName ∷ Int → String
nodeName number = "bumpusNode" <> show number

-- `nodes` numbers each argument type's node (design §13 rule 2).
entry
  ∷ Map Ty Int
  → { name ∷ String, parameters ∷ Array Ty, result ∷ Ty }
  → String
entry nodes wrapper =
  table wrapper.name "Kinds" (map kindOf placed.value)
    <> table wrapper.name "Slots" (map slotOf placed.value)
    <> "\nfunc "
    <> wrapper.name
    <> "Entry(e any) "
    <> goType wrapper.result
    <> " {\n"
    <> joinWith "" (Array.mapWithIndex (array placed.accum) distinct)
    <> "for p := "
    <> show (Array.length wrapper.parameters - 1)
    <> "; p >= 0; p-- {\nswitch "
    <> wrapper.name
    <> "Kinds[p] {\n"
    <> joinWith "" (Array.mapWithIndex (unpack nodes wrapper.name) distinct)
    <> "}\n}\nreturn "
    <> wrapper.name
    <> "("
    <> joinWith ", " (map argument placed.value)
    <> ")\n}\n"
  where
  distinct = Array.nub wrapper.parameters
  kinds = Map.fromFoldable (Array.mapWithIndex numbered distinct)
  numbered index ty = Tuple ty index
  placed = mapAccumL (place kinds) Map.empty wrapper.parameters
  kindOf found = found.kind
  slotOf found = found.slot

-- A package-level table, one entry per position.
table ∷ String → String → Array Int → String
table name suffix values = "\nvar " <> name <> suffix <> " = ["
  <> show (Array.length values)
  <> "]int32{"
  <> joinWith ", " (map show values)
  <> "}\n"

-- One array per distinct argument type, sized by its count.
array ∷ Map Int Int → Int → Ty → String
array counts kind ty = "var a" <> show kind <> " ["
  <> show (lookupOr kind counts)
  <> "]"
  <> goType ty
  <> "\n"

-- Each argument's kind, and its slot: how many of its kind came before.
place
  ∷ Map Ty Int
  → Map Int Int
  → Ty
  → { accum ∷ Map Int Int, value ∷ Placed }
place kinds counts ty =
  { accum: Map.insert kind (slot + 1) counts, value: { kind, slot } }
  where
  kind = lookupOr ty kinds
  slot = lookupOr kind counts

unpack ∷ Map Ty Int → String → Int → Ty → String
unpack nodes name kind ty = "case " <> show kind <> ":\nv := e.(*"
  <> nodeName (lookupOr ty nodes)
  <> ")\na"
  <> show kind
  <> "["
  <> name
  <> "Slots[p]] = v.value\ne = v.previous\n"

argument ∷ Placed → String
argument found = "a" <> show found.kind <> "[" <> show found.slot <> "]"

-- Every key looked up here was inserted from the same parameters; 0 only
-- for a compiler bug.
lookupOr ∷ ∀ k. Ord k ⇒ k → Map k Int → Int
lookupOr key found = maybe 0 identity (Map.lookup key found)
