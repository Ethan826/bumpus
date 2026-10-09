module Format.Parse.HandlerType (operand) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple (Tuple(..))
import Data.Traversable (traverse)
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( RowRef(..)
  , Span
  , TypeArgument(..)
  , TypeRef(..)
  , origin
  , problemAt
  )
import Format.Parse.Grammar
  ( Parser
  , expect
  , nested
  , optionalOn
  , refine
  , sepBy1
  , token
  )
import Format.Parse.Row (rowArgument, rowRef)
import Format.Lex (Token)

type Parsed =
  { arguments ∷ Array TypeArgument
  , row ∷ Maybe RowRef
  , close ∷ Token
  }

-- `single` reads one operand and leaves a following `with` unread, so the
-- row after an effect label belongs to the handler, not to the label.
operand ∷ Parser TypeRef → Parser TypeRef → Parser TypeRef
operand inner single = build <$> token
  <*> optionalOn "(" (parseArguments inner)
  where
  parseArguments parser = refine apply
    ( expect "(" *>
        ( parsed <$> sepBy1 "," (argument single)
            <*> optionalOn "with" (rowRef parser)
            <*> expect ")"
        )
    )
  parsed values row close = { arguments: values, row, close }
  apply found = maybe' (ordinary found) (special found) found.row
  ordinary found _ = Right
    ( NamedRef (applicationSpan found) "Handler"
        found.arguments
    )
  special found row = maybe' (missing found) (specialHead found row)
    (Array.uncons found.arguments)
  specialHead found row entry = case entry.head of
    TypeArgument (NamedRef labelSpan labelName labelArguments)
      | Array.null entry.tail → handler found row labelSpan labelName
          labelArguments
    TypeArgument reference → invalid reference
    RowArgument _ → invalid (IntRef (applicationSpan found))
  handler found row labelSpan labelName labelArguments = map
    (handlerType found row labelSpan labelName)
    (traverse effectArgument labelArguments)
  handlerType found row labelSpan labelName argumentRefs = THandlerRef
    (applicationSpan found)
    { name: labelName, arguments: argumentRefs, span: labelSpan }
    (Just row)
  effectArgument = case _ of
    TypeArgument reference → Right reference
    RowArgument (RowRef span _ _) → Left
      (problemAt (Syntax "Expected an effect label") span)
  invalid reference = Left
    (problemAt (Syntax "Expected an effect label") (typeRefSpan reference))
  missing found _ = Left
    (problemAt (Syntax "Expected an effect label") (applicationSpan found))
  applicationSpan found =
    { start: (argumentSpan found).start
    , end: found.close.span.end
    }
  argumentSpan found = maybe' unknownSpan argumentSpanOf
    (Array.head found.arguments)
  unknownSpan _ = { start: origin, end: origin }
  argumentSpanOf = case _ of
    TypeArgument reference → typeRefSpan reference
    RowArgument (RowRef span _ _) → span
  build keyword found = maybe' (bare keyword) (withStart keyword) found
  bare keyword _ = NamedRef keyword.span "Handler" []
  withStart keyword found = case found of
    NamedRef span name typeArgs → NamedRef
      (span { start = keyword.span.start })
      name
      typeArgs
    THandlerRef span effect row → THandlerRef
      (span { start = keyword.span.start })
      effect
      row
    _ → found

argument ∷ Parser TypeRef → Parser TypeArgument
argument inner = refine makeArgument
  (Tuple <$> nested inner <*> optionalOn "+" (expect "+" *> rowArgument inner))
  where
  makeArgument (Tuple found Nothing) = Right (TypeArgument found)
  makeArgument (Tuple found (Just row)) = rowArgumentFor found row
  rowArgumentFor found row = case found of
    NamedRef span name arguments → RowArgument
      <$> (addFirst span name <$> traverse asType arguments <*> pure row)
    _ → Left
      ( problemAt (Syntax "Expected an effect label")
          (typeRefSpan found)
      )
  asType = case _ of
    TypeArgument reference → Right reference
    RowArgument row → Left (problemAt (RowSort false) (rowSpan row))
  rowSpan (RowRef span _ _) = span

addFirst ∷ Span → String → Array TypeRef → RowRef → RowRef
addFirst span name arguments (RowRef rest labels tail) = RowRef
  { start: span.start, end: rest.end }
  (Array.cons { name, arguments, span } labels)
  tail

typeRefSpan ∷ TypeRef → Span
typeRefSpan = case _ of
  IntRef span → span
  BoolRef span → span
  UnitRef span → span
  VarRef span _ → span
  NamedRef span _ _ → span
  FunRef span _ _ _ → span
  THandlerRef span _ _ → span
