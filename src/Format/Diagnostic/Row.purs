module Format.Diagnostic.Row
  ( visibleLabels
  , pathHops
  , maxNotes
  , maxCharacters
  , equalityMessage
  , mismatchMessage
  , unabbreviated
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (maybe)
import Data.String (joinWith)
import Data.Tuple (Tuple(..), fst, snd)
import Domain.Problem (LabelName, Problem(..), RowText, TypeName(..))
import Format.Diagnostic.Name (listed, typeName)

-- Fixed bounds on a diagnostic (design §6, plan Task 9): the labels of a
-- row printed before the rest are counted, the hops of a call path kept at
-- each end, the notes that are not path lines, and all characters.
visibleLabels ∷ Int
visibleLabels = 4

pathHops ∷ Int
pathHops = 2

maxNotes ∷ Int
maxNotes = 4

maxCharacters ∷ Int
maxCharacters = 2000

-- `Clock + ...r and Log + ...r cannot be made equal: both end in ...r`,
-- each row abbreviated.
equalityMessage ∷ RowText → RowText → String → String
equalityMessage left right tail = abbreviated left <> " and "
  <> abbreviated right
  <> " cannot be made equal: both end in ..."
  <> tail

-- A row past `visibleLabels` labels prints the labels the other row lacks
-- first, then others up to the count, then how many more there are, and
-- always its tail, so a shared tail stays visible. Same-key labels are
-- never merged: each is one of the labels counted. A shorter row prints
-- in order, as it was written.
abbreviated ∷ RowText → String
abbreviated row = rendered (labelParts <> maybe [] Array.singleton row.tail)
  where
  total = Array.length row.labels
  labelParts =
    if total <= visibleLabels then map textOf row.labels
    else map textOf shown <> [ hidden ]
  shown = Array.take visibleLabels (differing <> others)
  differing = Array.filter _.differs row.labels
  others = Array.filter (not <<< _.differs) row.labels
  hidden = "… " <> show (total - visibleLabels) <> " more"
  rendered parts =
    if Array.null parts then "pure" else joinWith " + " parts

textOf ∷ { text ∷ String, differs ∷ Boolean } → String
textOf label = label.text

-- Every label, for a test to compare against the bound.
unabbreviated ∷ Problem → String
unabbreviated = case _ of
  RowEquality left right tail → full left <> " and " <> full right
    <> " cannot be made equal: both end in ..."
    <> tail
  _ → ""
  where
  full row = joinWith " + "
    (map textOf row.labels <> maybe [] Array.singleton row.tail)

-- `Expected State(Bool), found State(Int)`: the arguments off the path to
-- the difference are elided, so a large payload still shows where it
-- differs (`State(Pair(…, List(Bool)))`).
mismatchMessage ∷ LabelName → LabelName → String
mismatchMessage expected found = "Expected " <> labelText elidedExpected
  <> ", found "
  <> labelText elidedFound
  where
  Tuple elidedExpected elidedFound = elideLabels expected found

labelText ∷ LabelName → String
labelText label = label.effect <> listed (map typeName label.arguments)

elideLabels ∷ LabelName → LabelName → Tuple LabelName LabelName
elideLabels expected found =
  if
    expected.effect == found.effect
      && Array.length expected.arguments == Array.length found.arguments then
    Tuple (expected { arguments = map fst pairs })
      (found { arguments = map snd pairs })
  else Tuple expected found
  where
  pairs = Array.zipWith elide expected.arguments found.arguments

ellipsis ∷ TypeName
ellipsis = VariableName "…"

-- Equal siblings of the differing subterm become `…`; the differing
-- subterms are kept down to where they part. Function types are leaves.
elide ∷ TypeName → TypeName → Tuple TypeName TypeName
elide expected found
  | expected == found = Tuple ellipsis ellipsis
  | otherwise =
      case expected, found of
        AppliedName one expecteds, AppliedName other founds →
          elideApplied one other expecteds founds
        _, _ → Tuple expected found
      where
      elideApplied one other expecteds founds =
        if one == other && Array.length expecteds == Array.length founds then
          Tuple (AppliedName one (map fst pairs))
            (AppliedName other (map snd pairs))
        else Tuple expected found
        where
        pairs = Array.zipWith elide expecteds founds
