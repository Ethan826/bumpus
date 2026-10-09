-- Staged wrappers (FN001 design §13 rules 2-4, Amendment A1): a function
-- value of a named function, constructor or lifted lambda of arity n ≥ 2
-- is a chain of top-level stage functions over a linked environment, one
-- node per argument, ending in an entry that makes one n-ary call of the
-- function, so its body exists once. No Go closure is nested inside
-- another, and each stage costs one node and one closure, whatever the
-- arity or the number of distinct types (Task 1, round 3).
module Format.Go.Stage
  ( Nodes
  , stageTypes
  , valueName
  , staged
  ) where

import Prelude
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe)
import Data.String.Common (joinWith)
import Data.Traversable (mapAccumR)
import Data.Tuple (Tuple(..))
import Domain.IR.Internal (Ty(..))
import Format.Go.Data (goType)
import Format.Go.Entry (entry, nodeName)
import Format.Go.Lowered (Shape, Wrapper)

-- Each distinct argument type of the program's wrappers and its node
-- type's number (design §13 rule 2).
type Nodes = Map Ty Int

-- The value a wrapper starts as: its first stage, a Go function.
valueName ∷ Wrapper → String
valueName wrapper = wrapper.name <> "Value"

-- The Go types of the values awaiting arguments 1…j of the wrapper `name`
-- whose first j parameters are `parameters`, given the type `after` they
-- reach. Each is the interned arrow (design §13 rule 8) where Specialize
-- interned it; a stage no source expression has (a prefix of a partial
-- application, or of a lambda's free locals) gets the wrapper's own
-- `<name>Arrow<k>` (`ownType` below), except the first: only an
-- application helper's signature names that one (the wrapper's own
-- stages never do), so it is spelled `func(A1) <next>` and no type goes
-- unused. A suffix of an interned arrow is interned, so every use and
-- the wrapper itself agree on each name.
stageTypes ∷ Shape → String → Array Ty → Ty → Array String
stageTypes shape name parameters after =
  namedTypes name parameters after (interned shape parameters after)

-- Node types, then each wrapper once, in first-request order.
staged ∷ Shape → Array Wrapper → { nodes ∷ String, code ∷ String }
staged shape requested =
  { nodes: joinWith "" (Array.mapWithIndex nodeType distinct)
  , code: joinWith "" (map (wrapperCode shape numbers) wrappers)
  }
  where
  wrappers = Array.nubBy byName requested
  byName a b = compare a.name b.name
  distinct = Array.nub (Array.concatMap parametersOf wrappers)
  parametersOf wrapper = wrapper.parameters
  numbers = Map.fromFoldable (Array.mapWithIndex numbered distinct)
  numbered index ty = Tuple ty index

-- The interned arrow, if any, of the value awaiting each argument: from
-- the last parameter backwards, by (parameter, result) number pairs.
interned ∷ Shape → Array Ty → Ty → Array (Maybe Ty)
interned shape parameters after =
  (mapAccumR step (Just after) parameters).value
  where
  step known ty = found (known >>= lookup ty)
  lookup ty result = map TFun (Map.lookup (Tuple ty result) shape.arrows)
  found arrow = { accum: arrow, value: arrow }

namedTypes ∷ String → Array Ty → Ty → Array (Maybe Ty) → Array String
namedTypes name parameters after known = Array.mapWithIndex named known
  where
  named index = maybe (own index) goType
  own index
    | index == 0 = "func(" <> maybe "" goType (Array.head parameters) <> ") "
        <> maybe (goType after) identity (Array.index names 1)
    | otherwise = arrowName name (index + 1)
  names = Array.mapWithIndex later known
  later index = maybe (arrowName name (index + 1)) goType

arrowName ∷ String → Int → String
arrowName name position = name <> "Arrow" <> show position

nodeType ∷ Int → Ty → String
nodeType index ty = "type " <> nodeName index <> " struct { value "
  <> goType ty
  <> "; previous any }\n\n"

-- One wrapper and the Go types of its stage values (`stageTypes`).
type Staging = { wrapper ∷ Wrapper, types ∷ Array String, nodes ∷ Nodes }

wrapperCode ∷ Shape → Nodes → Wrapper → String
wrapperCode shape nodes wrapper =
  joinWith "" (Array.catMaybes (Array.mapWithIndex (ownType staging) known))
    <> firstStage staging
    <> joinWith ""
      ( map (laterStage staging)
          (Array.range 2 (Array.length wrapper.parameters))
      )
    <> entry nodes wrapper
  where
  known = interned shape wrapper.parameters wrapper.result
  staging =
    { wrapper
    , types: namedTypes wrapper.name wrapper.parameters wrapper.result known
    , nodes
    }

-- A stage value no interned arrow names gets its own type; the first is
-- spelled where it is used (`namedTypes`).
ownType ∷ Staging → Int → Maybe Ty → Maybe String
ownType staging index
  | index == 0 = const Nothing
  | otherwise = maybe (Just declaration) none
      where
      position = index + 1
      declaration = "\ntype " <> arrowName staging.wrapper.name position
        <> " func("
        <> parameter staging position
        <> ") "
        <> awaiting staging (position + 1)
        <> "\n"
      none _ = Nothing

firstStage ∷ Staging → String
firstStage staging = "\nfunc " <> valueName staging.wrapper <> "(x "
  <> parameter staging 1
  <> ") "
  <> awaiting staging 2
  <> " { return "
  <> stageName staging.wrapper 2
  <> "("
  <> node staging 1 "nil"
  <> ") }\n"

-- Stage k receives the chain of arguments 1…k-1 and returns the closure
-- taking argument k, which links one node and calls the next stage, or
-- the entry after the last.
laterStage ∷ Staging → Int → String
laterStage staging position = "\nfunc "
  <> stageName staging.wrapper position
  <> "(e any) "
  <> awaiting staging position
  <> " { return func(x "
  <> parameter staging position
  <> ") "
  <> awaiting staging (position + 1)
  <> " { return "
  <> next
  <> "("
  <> node staging position "e"
  <> ") } }\n"
  where
  last = position == Array.length staging.wrapper.parameters
  next =
    if last then staging.wrapper.name <> "Entry"
    else stageName staging.wrapper (position + 1)

-- The Go type of the value awaiting argument `position` (1-based); after
-- the last, the wrapped function's result.
awaiting ∷ Staging → Int → String
awaiting staging position = maybe (goType staging.wrapper.result) identity
  (Array.index staging.types (position - 1))

parameter ∷ Staging → Int → String
parameter staging position = maybe "" goType
  (Array.index staging.wrapper.parameters (position - 1))

-- A node holding argument `position`, linked to `previous`.
node ∷ Staging → Int → String → String
node staging position previous = "&" <> nodeOf <> "{x, " <> previous <> "}"
  where
  nodeOf = maybe "" (nodeName <<< numberOf)
    (Array.index staging.wrapper.parameters (position - 1))
  numberOf ty = maybe 0 identity (Map.lookup ty staging.nodes)

stageName ∷ Wrapper → Int → String
stageName wrapper position = wrapper.name <> "Stage" <> show position
