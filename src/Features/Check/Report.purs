module Features.Check.Report
  ( originNotes
  , originNotesVia
  , crossingNotes
  , boundaryNote
  , startingAt
  , noteAt
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Domain.Syntax (Note, NoteReason(..), Span)
import Features.Check.Occurrence (OccurrenceId(..))
import Features.Check.Provenance
  ( Boundary(..)
  , Consumed(..)
  , Hop
  , Origin
  )

-- A report's walk from a rejected occurrence, `first` being the origin of
-- the consumption that arrived at the rejection when the occurrence has
-- none of its own (the label never entered a row).
startingAt ∷ Origin → OccurrenceId → Array Hop → Array Hop
startingAt first occurrence hops = Array.cons
  { occurrence
  , origin: Just (maybe first identity (Array.head hops >>= ownOrigin))
  }
  (Array.drop 1 hops)
  where
  ownOrigin hop = hop.origin

noteAt ∷ Span → NoteReason → Note
noteAt span reason = { span, reason }

type Located = { origin ∷ Origin, index ∷ Int }

-- Where the label arose, nearest the rejection first: each origin that is
-- not the rejection's own span, as its consumption reads (`label`, the
-- label's text). The last origin of a call goes on into the callee: a
-- `ContinuesInto` marker at the call, which Features.Check replaces by the
-- path through the callee's body, as the callee's own check knows it.
originNotes ∷ Span → String → Array Hop → Array Note
originNotes primary label = originNotesVia (FromCallOf label) primary label

-- The same, a call of a function read as `call` says: a callee's own
-- calls are the path through it.
originNotesVia
  ∷ (String → NoteReason) → Span → String → Array Hop → Array Note
originNotesVia call primary label hops =
  noted <> maybe [] marker (Array.last located)
  where
  located = Array.catMaybes (Array.mapWithIndex withOrigin hops)
  withOrigin index hop = found index <$> hop.origin
  found index origin = { origin, index }
  noted = Array.mapMaybe note located
  note entry
    | entry.origin.span == primary = Nothing
    | otherwise = Just
        (noteAt entry.origin.span (reasonOf call label entry.origin))
  marker entry = case entry.origin.consumed of
    CallOf callee → maybe [] (continues callee entry)
      (position entry.origin.span hops entry.index)
    _ → []
  continues callee entry index = Array.singleton
    (noteAt entry.origin.span (ContinuesInto callee index label))

-- The position of a stage label within the call's row: the occurrence at
-- the origin's own span, or the one its link leads to.
position ∷ Span → Array Hop → Int → Maybe Int
position span hops index = Array.findMap positioned
  (Array.catMaybes [ Array.index hops index, Array.index hops (index + 1) ])
  where
  positioned hop = case hop.occurrence of
    Written at place | at == span → Just place
    _ → Nothing

reasonOf ∷ (String → NoteReason) → String → Origin → NoteReason
reasonOf call label origin = case origin.consumed of
  Operation _ → PerformedHere label
  CallOf callee → call callee
  Application → FromFunctionValue label
  FailOf _ → RaisedHere label

-- The boundaries a trail's origins crossed, where they were crossed.
crossingNotes ∷ String → Array Hop → Array Note
crossingNotes label hops = Array.mapMaybe crossing
  (Array.mapMaybe originOf hops)
  where
  originOf hop = hop.origin
  crossing origin = boundaryNote origin.span label <$> origin.via

-- A boundary, at its span, for a rejected `label`.
boundaryNote ∷ Span → String → Boundary → Note
boundaryNote span label = noteAt span <<< case _ of
  Signature name → SignatureForbids name label
  AmbientSignature name → SignatureAmbient name
  PureParameter → MustBePureParameter
  Installation handled → HandledHere handled
  Main → MainOnlyConsole
  DeferItem → CleanupMustNotFail
