module Format.Parse.Type (typeRef, typeAndRow) where

import Prelude
import Data.Array as Array
import Data.Array.NonEmpty (NonEmptyArray)
import Data.Array.NonEmpty as NonEmptyArray
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe, maybe')
import Data.Tuple (Tuple(..))
import Data.Traversable (traverse)
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( Diagnostic
  , Position
  , RowRef(..)
  , RowTail(..)
  , Span
  , TypeArgument(..)
  , TypeRef(..)
  , problemAt
  )
import Format.Parse.Row (rowArgument, rowRef)
import Format.Parse.HandlerType as HandlerType
import Format.Lex (Token, isName, isUpper)
import Format.Parse.Grammar
  ( Parser
  , chainRight
  , defer
  , dispatch
  , expect
  , failWith
  , grouped
  , nested
  , on
  , onWhen
  , optionalOn
  , refine
  , sepBy1
  , spanned
  , token
  , upperName
  )

type Applied = { identifier ∷ Token, arguments ∷ Maybe (Array TypeArgument) }

-- What one `->` separates: an operand, or a parenthesized list of types.
type Segment =
  { span ∷ Span
  , types ∷ NonEmptyArray TypeRef
  , row ∷ Maybe RowRef
  }

-- A parameter type and where its segment starts.
type Parameter =
  { start ∷ Position, ty ∷ TypeRef, row ∷ Maybe RowRef }

-- `->` is right-associative and loosest (FN001 design §1). The chain is
-- read as a list and folded right, never one recursion per arrow, and a
-- parameter is one nesting level deeper than its arrow (Grammar
-- `chainRight`). `(A, B) -> C` is `A -> B -> C`; `(A) -> B` is `A -> B`.
-- PureScript is strict, so the productions below receive `inner`, which
-- reaches `typeRef` lazily.
typeRef ∷ Parser TypeRef
typeRef = refine withoutRow typeAndRow
  where
  withoutRow found = maybe' (kept found) unexpectedRow found.row
  kept found _ = Right found.ty

typeAndRow ∷ Parser { ty ∷ TypeRef, row ∷ Maybe RowRef }
typeAndRow = refine combined (chainRight "->" (segment inner))
  where
  inner = defer later
  later _ = typeRef

-- Int, Bool, Unit, a type variable, or a capitalized name with optional type
-- arguments, each one nesting level deeper (ADR 006); otherwise E_SYNTAX at
-- that token. `List()` is rejected at `)`; `Int(a)` and `a(Int)` at `(`,
-- by whatever follows the type.
operand ∷ Parser TypeRef → Parser TypeRef
operand inner = dispatch
  [ on "Int" (IntRef <$> tokenSpan)
  , on "Bool" (BoolRef <$> tokenSpan)
  , on "Unit" (UnitRef <$> tokenSpan)
  , on "Handler" (HandlerType.operand (defer rowed) inner)
  , onWhen upperText (spanned appliedOf (parts <$> upperName <*> arguments))
  , onWhen lowerText (variable <$> token)
  ]
  (refine unknown token)
  where
  rowed _ = typeAndRow
  parts identifier found = { identifier, arguments: found }
  arguments = optionalOn "(" (expect "(" *> sepBy1 "," argument <* expect ")")
  argument = dispatch
    [ on "..." (spreadArgument inner)
    , on "pure" pureArgument
    ]
    (typeOrRow inner)
  pureRowArgument = spanned pureRow (expect "pure")
  pureRow span _ = RowRef span [] (Just Pure)
  spreadArgument parser = RowArgument <$> rowArgument parser
  pureArgument = RowArgument <$> pureRowArgument
  variable found = VarRef found.span found.text

-- A list of two or more types must be followed by `->`, which the chain
-- then reads, so the last segment of a chain is always a single type.
-- `()` is rejected at `)`, where a type is expected.
segment ∷ Parser TypeRef → Parser Segment
segment inner = spanned segmentOf
  ( parts
      <$> dispatch [ on "(" parenthesized ]
        (NonEmptyArray.singleton <$> operand inner)
      <*> optionalOn "with" (rowRef inner)
  )
  where
  parts types row = { types, row }
  segmentOf span found = { span, types: found.types, row: found.row }
  parenthesized = expect "(" *> grouped
    (NonEmptyArray.cons' <$> inner <*> dispatch [ on "," more ] closing)
  more = expect "," *> sepBy1 "," inner <* expect ")" <* arrowNext
  closing = [] <$ expect ")"
  arrowNext = dispatch [ on "->" (pure unit) ] (failWith "Expected ->")

-- Each arrow spans its parameter's segment through the chain's end; a
-- lone type keeps its own span, parenthesized or not.
folded ∷ { init ∷ Array Segment, last ∷ Segment } → TypeRef
folded chain = Array.foldr arrow (NonEmptyArray.last chain.last.types)
  ( Array.concat
      ( Array.zipWith annotated chain.init
          (Array.drop 1 chain.init <> [ chain.last ])
      ) <> lastParameters
  )
  where
  end = chain.last.span.end
  lastParameters = map (startingAt chain.last.span.start)
    (NonEmptyArray.init chain.last.types)
  arrow parameter result =
    FunRef { start: parameter.start, end } parameter.ty parameter.row result
  annotated before after = setLast after.row (parameters before)
  setLast row found = fromMaybe found
    (Array.modifyAt (Array.length found - 1) (withRow row) found)
  withRow row parameter = parameter { row = row }

parameters ∷ Segment → Array Parameter
parameters found = map (startingAt found.span.start)
  (NonEmptyArray.toArray found.types)

startingAt ∷ Position → TypeRef → Parameter
startingAt start ty = { start, ty, row: Nothing }

-- A row follows the chain's last segment: it is the signature's row for a
-- lone type, or the final arrow's row. Only the first segment of an arrow
-- chain has no arrow before it, so a row there would be dropped; reject it.
combined
  ∷ { init ∷ Array Segment, last ∷ Segment }
  → Either Diagnostic { ty ∷ TypeRef, row ∷ Maybe RowRef }
combined chain = maybe' (merged chain) unexpectedRow (leadingRow chain)

-- The row written on the chain's first segment, if there is an arrow after it.
leadingRow ∷ { init ∷ Array Segment, last ∷ Segment } → Maybe RowRef
leadingRow chain = maybe' (const Nothing) segmentRow (Array.head chain.init)

merged
  ∷ { init ∷ Array Segment, last ∷ Segment }
  → Unit
  → Either Diagnostic { ty ∷ TypeRef, row ∷ Maybe RowRef }
merged chain _ = Right
  { ty: folded chain
  , row: if Array.null chain.init then chain.last.row else Nothing
  }

segmentRow ∷ Segment → Maybe RowRef
segmentRow found = found.row

-- A row with no meaning where it was written is an error, never dropped.
unexpectedRow ∷ ∀ a. RowRef → Either Diagnostic a
unexpectedRow (RowRef span _ _) = Left
  (problemAt (Syntax "Unexpected effect row") span)

appliedOf ∷ Span → Applied → TypeRef
appliedOf span found =
  NamedRef span found.identifier.text (fromMaybe [] found.arguments)

typeOrRow ∷ Parser TypeRef → Parser TypeArgument
typeOrRow inner = refine makeArgument
  ( Tuple <$> nested inner
      <*> optionalOn "+" (expect "+" *> rowArgument inner)
  )
  where
  makeArgument (Tuple first Nothing) = Right (TypeArgument first)
  makeArgument (Tuple first (Just rest)) = rowArgumentFor first rest
  rowArgumentFor first rest = case first of
    NamedRef span name arguments →
      RowArgument <$>
        ( addFirst span name <$> traverse typeArgument arguments
            <*> pure rest
        )
    _ → expectedLabel first
  expectedLabel first = Left
    (problemAt (Syntax "Expected an effect label") (typeRefSpan first))
  typeArgument = case _ of
    TypeArgument found → Right found
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

unknown ∷ Token → Either Diagnostic TypeRef
unknown found = Left (problemAt (Syntax "Expected a type") found.span)

tokenSpan ∷ Parser Span
tokenSpan = spanOf <$> token
  where
  spanOf found = found.span

upperText ∷ String → Boolean
upperText text = isName text && isUpper text

lowerText ∷ String → Boolean
lowerText text = isName text && not (isUpper text)
