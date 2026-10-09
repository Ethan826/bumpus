module Format.Parse.HandlerType (operand) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple (Tuple(..))
import Data.Tuple as Tuple
import Data.Traversable (traverse)
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( Diagnostic
  , RowRef(..)
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

type Rowed = { ty ∷ TypeRef, row ∷ Maybe RowRef }

type Parsed =
  { arguments ∷ Array TypeArgument
  , argumentRows ∷ Array RowRef
  , row ∷ Maybe RowRef
  , close ∷ Token
  }

-- Arguments are full types (`rowed` reads a chain and its trailing row), as
-- they were before rows were kept. A `with` after the sole argument is then
-- read by that argument's chain, so `apply` lifts it to be the handler's row.
operand ∷ Parser Rowed → Parser TypeRef → Parser TypeRef
operand rowed inner = build <$> token
  <*> optionalOn "(" (parseArguments inner)
  where
  parseArguments parser = refine apply
    ( expect "(" *>
        ( parsed <$> sepBy1 "," (argument rowed parser)
            <*> optionalOn "with" (rowRef parser)
            <*> expect ")"
        )
    )
  parsed values row close =
    { arguments: map Tuple.fst values
    , argumentRows: Array.mapMaybe Tuple.snd values
    , row
    , close
    }
  apply found = either Left (withRow found) (liftedRow found)
  withRow found row = maybe' (ordinary found) (special found) row
  liftedRow found = maybe' (kept found) (sole found)
    (Array.head found.argumentRows)
  kept found _ = Right found.row
  sole found first
    | Array.length found.arguments == 1 = maybe' (lifted first)
        (Left <<< unexpectedRow)
        found.row
    | otherwise = Left (unexpectedRow first)
  lifted first _ = Right (Just first)
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

argument
  ∷ Parser Rowed → Parser TypeRef → Parser (Tuple TypeArgument (Maybe RowRef))
argument rowed inner = refine makeArgument
  (Tuple <$> nested rowed <*> optionalOn "+" (expect "+" *> rowArgument inner))
  where
  makeArgument (Tuple found Nothing) = Right
    (Tuple (TypeArgument found.ty) found.row)
  makeArgument (Tuple found (Just row)) = rowArgumentFor found row
  rowArgumentFor found row = case found.ty of
    NamedRef span name arguments → withoutRow found.row
      <$> (addFirst span name <$> traverse asType arguments <*> pure row)
    _ → Left
      ( problemAt (Syntax "Expected an effect label")
          (typeRefSpan found.ty)
      )
  withoutRow row built = Tuple (RowArgument built) row
  asType = case _ of
    TypeArgument reference → Right reference
    RowArgument row → Left (problemAt (RowSort false) (rowSpan row))
  rowSpan (RowRef span _ _) = span

unexpectedRow ∷ RowRef → Diagnostic
unexpectedRow (RowRef span _ _) =
  problemAt (Syntax "Unexpected effect row") span

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
