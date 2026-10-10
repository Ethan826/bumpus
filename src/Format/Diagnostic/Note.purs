module Format.Diagnostic.Note (WireNote, wireNotes, noteText) where

import Prelude
import Data.Array as Array
import Data.Array.NonEmpty as NonEmpty
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..), maybe)
import Data.String as String
import Data.Traversable (mapAccumL)
import Domain.Syntax (Note, NoteReason(..), Span)
import Format.Diagnostic.Row
  ( maxCharacters
  , maxNotes
  , pathHops
  , shortLabel
  )

-- A note as the wire carries it: its span and rendered text.
type WireNote = { span ∷ Span, message ∷ String }

-- The notes of a diagnostic whose message is `message`, rendered and
-- bounded (design §6): a run of call-path hops keeps `pathHops` hops at
-- each end with `… k more calls` between; past `maxNotes` notes that are
-- not path lines the last is kept and the middle ones dropped; and notes
-- that would take the diagnostic past `maxCharacters` are left out.
wireNotes ∷ String → Array Note → Array WireNote
wireNotes message notes = withinCharacters message
  (map rendered (limited (elided (Array.filter written notes))))
  where
  written note = case note.reason of
    ContinuesInto _ _ _ → false
    _ → true
  rendered note = { span: note.span, message: noteText note.reason }

-- A run of path hops longer than twice `pathHops` loses its middle.
elided ∷ Array Note → Array Note
elided notes = Array.concatMap shortened
  (map NonEmpty.toArray (Array.groupBy bothHops notes))
  where
  bothHops one other = isHop one && isHop other

isHop ∷ Note → Boolean
isHop note = case note.reason of
  ThroughFunction _ → true
  _ → false

isPath ∷ Note → Boolean
isPath note = isHop note || case note.reason of
  MoreCalls _ → true
  _ → false

shortened ∷ Array Note → Array Note
shortened run =
  if hidden <= 0 then run
  else Array.take pathHops run <> maybe [] gap (Array.index run pathHops)
    <> Array.takeEnd pathHops run
  where
  hidden = Array.length run - 2 * pathHops
  gap first = [ { span: first.span, reason: MoreCalls hidden } ]

-- Past `maxNotes` notes that are not path lines, the last is kept with the
-- first ones: it is the boundary that refuses the label.
limited ∷ Array Note → Array Note
limited notes = Array.mapMaybe kept (mapAccumL rank 0 notes).value
  where
  rank seen note =
    { accum: if isPath note then seen else seen + 1, value: { note, seen } }
  plainTotal = Array.length (Array.filter (not <<< isPath) notes)
  kept entry =
    if
      isPath entry.note || plainTotal <= maxNotes
        || entry.seen < maxNotes - 1
        || entry.seen == plainTotal - 1 then Just entry.note
    else Nothing

withinCharacters ∷ String → Array WireNote → Array WireNote
withinCharacters message notes = (foldl add start notes).kept
  where
  start = { used: String.length message, kept: [] }
  add found note =
    if found.used + String.length note.message > maxCharacters then found
    else
      { used: found.used + String.length note.message
      , kept: Array.snoc found.kept note
      }

noteText ∷ NoteReason → String
noteText = case _ of
  PerformedHere label → shortLabel label <> " is performed here"
  FromCallOf label callee → shortLabel label <> " comes from this call of " <>
    callee
  FromFunctionValue label → shortLabel label <>
    " comes from this function value"
  RaisedHere label → shortLabel label <> " is raised here"
  ThroughFunction callee → "through " <> callee
  MoreCalls count → "… " <> show count <> " more calls"
  SignatureForbids callee label → "the signature of " <> callee
    <> " does not allow "
    <> shortLabel label
  SignatureAmbient callee → "the signature of " <> callee
    <> " has an ambient row"
  MustBePureParameter → "this parameter must be pure"
  HandledHere label → shortLabel label <> " is handled here"
  MainOnlyConsole → "main may perform only Console"
  CleanupMustNotFail → "cleanup registered here must not fail"
  NoFamilyHere → "this failure has no concrete error family"
  FailAlternatives →
    "use ...e to pass through what a callback performs, a concrete "
      <> "family such as Fail(DbError), or return a Result"
  DeclaredHere name → name <> " is declared here"
  InnermostHere label → "the innermost " <> shortLabel label <> " is here"
  ContinuesInto _ _ _ → ""
