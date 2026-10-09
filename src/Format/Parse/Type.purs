module Format.Parse.Type (typeRef) where

import Prelude
import Data.Array as Array
import Data.Array.NonEmpty (NonEmptyArray)
import Data.Array.NonEmpty as NonEmptyArray
import Data.Either (Either(..))
import Data.Maybe (Maybe, fromMaybe)
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Position, Span, TypeRef(..), problemAt)
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

type Applied = { identifier ∷ Token, arguments ∷ Maybe (Array TypeRef) }

-- What one `->` separates: an operand, or a parenthesized list of types.
type Segment = { span ∷ Span, types ∷ NonEmptyArray TypeRef }

-- A parameter type and where its segment starts.
type Parameter = { start ∷ Position, ty ∷ TypeRef }

-- `->` is right-associative and loosest (FN001 design §1). The chain is
-- read as a list and folded right, never one recursion per arrow, and a
-- parameter is one nesting level deeper than its arrow (Grammar
-- `chainRight`). `(A, B) -> C` is `A -> B -> C`; `(A) -> B` is `A -> B`.
-- PureScript is strict, so the productions below receive `inner`, which
-- reaches `typeRef` lazily.
typeRef ∷ Parser TypeRef
typeRef = folded <$> chainRight "->" (segment inner)
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
  , onWhen upperText (spanned appliedOf (parts <$> upperName <*> arguments))
  , onWhen lowerText (variable <$> token)
  ]
  (refine unknown token)
  where
  parts identifier found = { identifier, arguments: found }
  arguments = optionalOn "(" (expect "(" *> sepBy1 "," argument <* expect ")")
  argument = nested inner
  variable found = VarRef found.span found.text

-- A list of two or more types must be followed by `->`, which the chain
-- then reads, so the last segment of a chain is always a single type.
-- `()` is rejected at `)`, where a type is expected.
segment ∷ Parser TypeRef → Parser Segment
segment inner = spanned segmentOf
  ( dispatch [ on "(" parenthesized ]
      (NonEmptyArray.singleton <$> operand inner)
  )
  where
  segmentOf span types = { span, types }
  parenthesized = expect "(" *> grouped
    (NonEmptyArray.cons' <$> inner <*> dispatch [ on "," more ] closing)
  more = expect "," *> sepBy1 "," inner <* expect ")" <* arrowNext
  closing = [] <$ expect ")"
  arrowNext = dispatch [ on "->" (pure unit) ] (failWith "Expected ->")

-- Each arrow spans its parameter's segment through the chain's end; a
-- lone type keeps its own span, parenthesized or not.
folded ∷ { init ∷ Array Segment, last ∷ Segment } → TypeRef
folded chain = Array.foldr arrow (NonEmptyArray.last chain.last.types)
  (Array.concatMap parameters chain.init <> lastParameters)
  where
  end = chain.last.span.end
  lastParameters = map (startingAt chain.last.span.start)
    (NonEmptyArray.init chain.last.types)
  arrow parameter result =
    FunRef { start: parameter.start, end } parameter.ty result

parameters ∷ Segment → Array Parameter
parameters found = map (startingAt found.span.start)
  (NonEmptyArray.toArray found.types)

startingAt ∷ Position → TypeRef → Parameter
startingAt start ty = { start, ty }

appliedOf ∷ Span → Applied → TypeRef
appliedOf span found =
  NamedRef span found.identifier.text (fromMaybe [] found.arguments)

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
