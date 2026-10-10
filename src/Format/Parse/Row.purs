module Format.Parse.Row (rowRef, rowArgument, label) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe)
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( LabelRef
  , RowRef(..)
  , RowTail(..)
  , Span
  , TypeRef
  , origin
  , problemAt
  )
import Format.Parse.Grammar
  ( Parser
  , dispatch
  , expect
  , name
  , on
  , optionalOn
  , refine
  , sepBy1
  , spanned
  , upperName
  )

rowRef ∷ Parser TypeRef → Parser RowRef
rowRef inner = spanned rowOf
  ( expect "with" *> dispatch
      [ on "pure" (pureRow <$ expect "pure") ]
      ordinary
  )
  where
  pureRow = { labels: [], tail: Just Pure }
  ordinary = gathered <$> validatedParts inner
  rowOf span found = RowRef span found.labels found.tail

label ∷ Parser TypeRef → Parser LabelRef
label inner = spanned labelOf
  ( parts <$> upperName
      <*> optionalOn "(" arguments
  )
  where
  arguments = expect "(" *> sepBy1 "," inner <* expect ")"
  parts identifier found =
    { name: identifier.text, arguments: fromMaybe [] found }
  labelOf span found = { name: found.name, arguments: found.arguments, span }

rowArgument ∷ Parser TypeRef → Parser RowRef
rowArgument inner = spanned rowOf (gathered <$> validatedParts inner)
  where
  rowOf span found = RowRef span found.labels found.tail

gathered ∷ Array Part → { labels ∷ Array LabelRef, tail ∷ Maybe RowTail }
gathered parts =
  { labels: Array.mapMaybe labelPart parts, tail: lastTail parts }

data Part = LabelPart LabelRef | TailPart RowTail Span

rowPart ∷ Parser TypeRef → Parser Part
rowPart inner = dispatch [ on "..." spreadPart ]
  (LabelPart <$> label inner)
  where
  spreadPart = tailPart <$> expect "..." <*> name
  tailPart marker found = TailPart (Spread found.text)
    { start: marker.span.start, end: found.span.end }

validatedParts ∷ Parser TypeRef → Parser (Array Part)
validatedParts inner = refine validate (sepBy1 "+" (rowPart inner))
  where
  validate parts = case tails of
    [] → Right parts
    [ tail ] →
      if tail.index == Array.length parts - 1 then Right parts
      else invalid "Row tail must be last" tail.span
    _ → invalid "Only one row tail is allowed" (secondTail tails).span
    where
    tails = Array.mapMaybe identity
      ( Array.zipWith tailAt
          (Array.range 0 (Array.length parts - 1))
          parts
      )
    tailAt index = case _ of
      TailPart _ span → Just { index, span }
      _ → Nothing
  secondTail tails = fromMaybe { index: 0, span: nowhere }
    (Array.index tails 1)
  invalid message span = Left (problemAt (Syntax message) span)
  nowhere = { start: origin, end: origin }

labelPart ∷ Part → Maybe LabelRef
labelPart = case _ of
  LabelPart labelValue → Just labelValue
  _ → Nothing

tailPartValue ∷ Part → Maybe RowTail
tailPartValue = case _ of
  TailPart tail _ → Just tail
  _ → Nothing

lastTail ∷ Array Part → Maybe RowTail
lastTail = Array.last <<< Array.mapMaybe tailPartValue
