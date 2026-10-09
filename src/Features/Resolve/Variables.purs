module Features.Resolve.Variables
  ( signatureVariables
  , sortedVariables
  , uniqueTypeParameters
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldM, traverse_)
import Data.Maybe (Maybe(..), maybe)
import Data.Traversable (mapAccumL)
import Domain.Problem (DuplicateKind(..), Problem(..))
import Domain.Syntax as Syntax
import Features.Resolve.Repeated (laterRepeat)

-- A function's type variables are implicitly quantified over its whole
-- signature: every lowercase name in its parameter and result types, in
-- first-occurrence order, so `VarId i` is the i-th of them.
signatureVariables ∷ Array Syntax.TypeRef → Array String
signatureVariables references =
  Array.nub (Array.concatMap occurrences references)

-- A type parameter that repeats an earlier one of its declaration is
-- reported at the repetition, declaration by declaration.
uniqueTypeParameters ∷ Array Syntax.TypeDecl → Either Syntax.Diagnostic Unit
uniqueTypeParameters = traverse_ uniqueIn
  where
  uniqueIn declaration = traverse_ duplicate
    ( laterRepeat (map name declaration.parameters)
        >>= Array.index declaration.parameters
    )
  name parameter = parameter.name
  duplicate parameter = Left
    ( Syntax.problemAt (Duplicate DuplicateTypeParameter parameter.name)
        parameter.span
    )

occurrences ∷ Syntax.TypeRef → Array String
occurrences = case _ of
  Syntax.IntRef _ → []
  Syntax.BoolRef _ → []
  Syntax.UnitRef _ → []
  Syntax.VarRef _ name → [ name ]
  Syntax.NamedRef _ _ arguments → Array.concatMap argumentNames arguments
  Syntax.THandlerRef _ label row → labelOccurrences label
    <> maybe [] rowVariableNames row
  arrow@(Syntax.FunRef _ _ _ _) → spineOccurrences (Syntax.typeRefSpine arrow)
  where
  spineOccurrences found = Array.concatMap occurrences
    (Array.snoc found.parameters found.result)

-- Sort disagreements are diagnosed at the second written occurrence.
sortedVariables
  ∷ Array Syntax.TypeRef
  → Maybe Syntax.RowRef
  → Either Syntax.Diagnostic (Array { name ∷ String, sort ∷ Syntax.Sort })
sortedVariables references row = foldM insert []
  ( Array.sortWith offset
      ( Array.concatMap typeOccurrences references <> maybe [] rowOccurrences
          row
      )
  )
  where
  offset occurrence = occurrence.span.start.offset
  insert found occurrence = maybe (Right (Array.snoc found (named occurrence)))
    (same found occurrence)
    (Array.find (matching occurrence.name) found)
  named occurrence = { name: occurrence.name, sort: occurrence.sort }
  matching name entry = entry.name == name
  same found occurrence previous
    | occurrence.sort == previous.sort = Right found
    | otherwise = Left
        ( Syntax.problemAt
            (RowSort (occurrence.sort == Syntax.RowSort))
            occurrence.span
        )

type Occurrence = { name ∷ String, sort ∷ Syntax.Sort, span ∷ Syntax.Span }

typeOccurrences ∷ Syntax.TypeRef → Array Occurrence
typeOccurrences = case _ of
  Syntax.VarRef span name → [ { name, span, sort: Syntax.TypeSort } ]
  Syntax.NamedRef _ _ arguments → Array.concatMap argumentOccurrences arguments
  Syntax.THandlerRef _ label row → labelTypeOccurrences label
    <> maybe [] rowOccurrences row
  arrow@(Syntax.FunRef _ _ _ _) → arrowOccurrences arrow
  _ → []

argumentNames ∷ Syntax.TypeArgument → Array String
argumentNames = case _ of
  Syntax.TypeArgument reference → occurrences reference
  Syntax.RowArgument row → rowVariableNames row
    <> Array.concatMap labelNames (rowLabels row)

labelNames ∷ Syntax.LabelRef → Array String
labelNames label = Array.concatMap occurrences label.arguments

rowLabels ∷ Syntax.RowRef → Array Syntax.LabelRef
rowLabels (Syntax.RowRef _ labels _) = labels

argumentOccurrences ∷ Syntax.TypeArgument → Array Occurrence
argumentOccurrences = case _ of
  Syntax.TypeArgument reference → typeOccurrences reference
  Syntax.RowArgument row → rowOccurrences row

-- Collect the right spine by loops; annotations on each stage still
-- contribute variables, ordered by source offset in sortedVariables.
arrowOccurrences ∷ Syntax.TypeRef → Array Occurrence
arrowOccurrences reference =
  Array.concatMap typeOccurrences
    (Array.snoc spine.parameters spine.result)
    <> Array.concatMap (maybe [] rowOccurrences) taken.value
  where
  spine = Syntax.typeRefSpine reference
  taken = mapAccumL next reference
    (Array.replicate (Array.length spine.parameters) unit)
  next (Syntax.FunRef _ _ row result) _ = { accum: result, value: row }
  next result _ = { accum: result, value: Nothing }

rowOccurrences ∷ Syntax.RowRef → Array Occurrence
rowOccurrences (Syntax.RowRef span labels tail) =
  Array.concatMap arguments labels <> maybe [] ending tail
  where
  arguments label = Array.concatMap typeOccurrences label.arguments
  ending Syntax.Pure = []
  ending (Syntax.Spread name) = [ { name, span, sort: Syntax.RowSort } ]

labelOccurrences ∷ Syntax.LabelRef → Array String
labelOccurrences label = Array.concatMap occurrences label.arguments

labelTypeOccurrences ∷ Syntax.LabelRef → Array Occurrence
labelTypeOccurrences label = Array.concatMap typeOccurrences label.arguments

rowVariableNames ∷ Syntax.RowRef → Array String
rowVariableNames reference = map name (rowOccurrences reference)
  where
  name occurrence = occurrence.name
