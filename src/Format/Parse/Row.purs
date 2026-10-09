module Format.Parse.Row (rowRef) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), fromMaybe)
import Domain.Syntax (LabelRef, RowRef(..), RowTail(..), TypeRef)
import Format.Parse.Grammar
  ( Parser
  , dispatch
  , expect
  , name
  , on
  , optionalOn
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
  ordinary = gathered <$> sepBy1 "+" component
  component = dispatch [ on "..." (Right <$> spread) ] (Left <$> label inner)
  gathered parts =
    { labels: Array.mapMaybe (either Just noLabel) parts
    , tail: Array.last (Array.mapMaybe (either noTail Just) parts)
    }
  noLabel _ = Nothing
  noTail _ = Nothing
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

spread ∷ Parser RowTail
spread = Spread <$> (expect "..." *> identifier)
  where
  identifier = text <$> name
  text found = found.text
