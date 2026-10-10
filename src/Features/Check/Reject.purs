module Features.Check.Reject
  ( rejected
  , siteOccurrence
  , rightSpan
  , declaredNote
  , signature
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe, maybe')
import Domain.Checked.Internal (Open(..))
import Domain.Problem (Problem(..))
import Domain.Row (Row(..))
import Domain.Syntax (Diagnostic, Note, NoteReason(..), Span, problemAt)
import Domain.Type (VarId(..))
import Features.Check.Context (CheckEnv)
import Features.Check.Occurrence (OccurrenceId(..))
import Features.Check.Provenance (Boundary(..), Hop, Origin, trail)
import Features.Check.Report
  ( boundaryNote
  , crossingNotes
  , noteAt
  , originNotes
  , startingAt
  )
import Features.Check.RowName (labelName, labelView, rowConflict)
import Features.Check.Scheme (State, opened)
import Features.Check.TypeName (typeName)
import Features.Check.Unify (Failure(..))

-- A consumption (or the retry of a postponed one) that failed, reported at
-- the consuming span with the notes the state can give: where the label
-- arose, and the boundary that refuses it (design §6).
rejected
  ∷ ∀ r a. CheckEnv r → State → Origin → Failure → Either Diagnostic a
rejected env state origin failure = case failure of
  Mismatch found expected → mismatch expected found
  RowMissing label _ occurrence → notAllowed label occurrence
  RowExtra label occurrence → notAllowed label occurrence
  RowSharedTail left right → conflict left right
  RowMismatch left right → conflict left right
  RowPayload found expected occurrence → payload found expected occurrence
  _ → Left (problemAt (Internal "Effect row consumption failed") span)
  where
  span = origin.span
  mismatch expected found = do
    expectedName ← typeName env span (opened expected)
    foundName ← typeName env span (opened found)
    Left (problemAt (TypeMismatch expectedName foundName) span)
  notAllowed label occurrence = do
    name ← labelName env span label
    Left
      { problem: EffectNotAllowed env.functionName name
      , span
      , related: originNotes span name (hops occurrence)
          <> crossingNotes name (hops occurrence)
          <> [ boundaryNote env.functionSpan name (signature env) ]
      }
  hops occurrence = startingAt origin occurrence (walk occurrence)
  walk occurrence = trail state.subst state.origins
    (siteOccurrence env occurrence)
  conflict left right = either (Left <<< declared) Right
    (rowConflict env span left right)
  declared diagnostic = diagnostic
    { related = declaredNote env.functionSpan diagnostic.problem }
  payload found expected occurrence = do
    expectedName ← labelView env span expected
    foundName ← labelView env span found
    shown ← labelName env span expected
    Left
      { problem: LabelMismatch expectedName foundName
      , span
      , related: innermost shown (walk occurrence)
      }

-- The innermost entry of the mismatched key is where its occurrence was
-- written (a signature or an installation), or, for an extension, where
-- it first arose.
innermost ∷ String → Array Hop → Array Note
innermost shown hops = maybe [] noted (Array.head hops)
  where
  noted hop = case hop.occurrence of
    Written site _ → [ noteAt site (InnermostHere shown) ]
    Extended _ → maybe [] (Array.singleton <<< arose) hop.origin
  arose origin = noteAt origin.span (InnermostHere shown)

-- The boundary refusing a label: the signature, or its ambient row.
signature ∷ ∀ r. CheckEnv r → Boundary
signature env =
  if ambient env.current then AmbientSignature env.functionName
  else Signature env.functionName
  where
  ambient (Row _ tail) = maybe false named tail
  named = case _ of
    Rigid (VarId index) → Array.index env.variables index == Just ""
    Hole _ → false

-- `...r is declared here`, for the shared tail of a conflict.
declaredNote ∷ Span → Problem → Array Note
declaredNote span = case _ of
  RowEquality _ _ tail
    | tail /= "" → [ noteAt span (DeclaredHere ("..." <> tail)) ]
  _ → []

-- An occurrence as the current row's sites name it. Unification numbers
-- the current row's own labels from its innermost site's span; a
-- `with` or `handle` around the consumption put its own labels first, so
-- the position says which site wrote the label.
siteOccurrence ∷ ∀ r. CheckEnv r → OccurrenceId → OccurrenceId
siteOccurrence env occurrence = case occurrence of
  Written span position | span == rightSpan env → placed env position
  _ → occurrence

placed ∷ ∀ r. CheckEnv r → Int → OccurrenceId
placed env position = tailRec step { rest: env.sites, position }
  where
  step pending = maybe' (outside pending) (inSite pending)
    (Array.uncons pending.rest)
  outside pending _ = Done (Written (rightSpan env) pending.position)
  inSite pending found =
    if pending.position < found.head.count then Done
      (Written found.head.span pending.position)
    else Loop
      { rest: found.tail, position: pending.position - found.head.count }

rightSpan ∷ ∀ r. CheckEnv r → Span
rightSpan env = maybe env.functionSpan _.span (Array.head env.sites)
