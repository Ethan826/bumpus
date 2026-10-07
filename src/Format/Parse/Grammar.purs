module Format.Parse.Grammar
  ( module Exports
  , Parser
  , Case
  , token
  , expect
  , name
  , upperName
  , failWith
  , refine
  , defer
  , on
  , onWhen
  , dispatch
  , optionalOn
  , sepBy1
  , sepByTrailing1
  , commaList
  , chainLeft1
  , spanned
  , run
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe, maybe')
import Domain.Syntax (Diagnostic, Span)
import Format.Lex (Token, isName, isUpper)
import Format.Parse.Cursor (Parsed, Run, State, initialState) as Exports
import Format.Parse.Cursor
  ( Run
  , State
  , advance
  , current
  , failAt
  , nextSpan
  , peekText
  , skip
  )
import Format.Stack as Stack

-- Applicative only (no Bind): choice is LL(1) on the next token (dispatch),
-- and the remaining input is threaded here and nowhere else.
newtype Parser a = Parser (Run a)

type Case a = { accepts ∷ String → Boolean, parser ∷ Parser a }

-- After a list item: resume (Loop) at the next item or end (Done).
type Continue = State → Step State State

instance Functor Parser where
  map transform (Parser parser) = Parser (mapAt transform parser)

instance Apply Parser where
  apply (Parser function) (Parser argument) =
    Parser (applyAt function argument)

instance Applicative Parser where
  pure value = Parser (pureAt value)

token ∷ Parser Token
token = Parser takeAt

expect ∷ String → Parser Token
expect text = dispatch [ on text token ]
  (failWith ("Expected '" <> text <> "'"))

name ∷ Parser Token
name = dispatch [ onWhen isName token ] (failWith "Expected an identifier")

upperName ∷ Parser Token
upperName = dispatch [ onWhen upperText token ]
  (failWith "Expected a capitalized name")
  where
  upperText text = isName text && isUpper text

-- E_SYNTAX at the next token, or as an empty span at end of input.
failWith ∷ ∀ a. String → Parser a
failWith message = Parser (flip failAt message)

-- A fallible map: checks a parsed value without consuming more input.
refine ∷ ∀ a b. (a → Either Diagnostic b) → Parser a → Parser b
refine check (Parser parser) = Parser (refineAt check parser)

-- PureScript is strict, so recursive productions delay their reference.
defer ∷ ∀ a. (Unit → Parser a) → Parser a
defer later = Parser (deferAt later)

on ∷ ∀ a. String → Parser a → Case a
on text parser = { accepts: eq text, parser }

onWhen ∷ ∀ a. (String → Boolean) → Parser a → Case a
onWhen accepts parser = { accepts, parser }

-- The first case accepting the next token's text (`<end>` at end of
-- input), else the fallback. Nothing is consumed before the choice.
dispatch ∷ ∀ a. Array (Case a) → Parser a → Parser a
dispatch cases fallback = Parser (dispatchAt cases fallback)

optionalOn ∷ ∀ a. String → Parser a → Parser (Maybe a)
optionalOn text parser = dispatch [ on text (Just <$> parser) ]
  (pure Nothing)

sepBy1 ∷ ∀ a. String → Parser a → Parser (Array a)
sepBy1 separator item = collect (separated separator) item

-- A separator directly before `close` ends the list; `close` is left.
sepByTrailing1 ∷ ∀ a. String → String → Parser a → Parser (Array a)
sepByTrailing1 separator close item =
  collect (trailing separator close) item

-- Empty exactly when the next token is `)`, which is left for the caller.
commaList ∷ ∀ a. Parser a → Parser (Array a)
commaList item = dispatch [ on ")" (pure []) ] (sepBy1 "," item)

-- Folds left in a loop: a `op` b `op` c is (a `op` b) `op` c.
chainLeft1 ∷ ∀ a. String → (a → a → a) → Parser a → Parser a
chainLeft1 operator combine item =
  Parser (foldAt (separated operator) identity combine (run item))

-- From the first to the last consumed token; an empty span at the next
-- token's start if nothing was consumed.
spanned ∷ ∀ a b. (Span → a → b) → Parser a → Parser b
spanned build (Parser parser) = Parser (spannedAt build parser)

-- Runs a whole production from a state; the declaration loop steps with it.
run ∷ ∀ a. Parser a → Run a
run (Parser parser) = parser

applyAt ∷ ∀ a b. Run (a → b) → Run a → Run b
applyAt function argument state = do
  applied ← function state
  given ← argument applied.rest
  pure { value: applied.value given.value, rest: given.rest }

mapAt ∷ ∀ a b. (a → b) → Run a → Run b
mapAt transform parser state = map mapped (parser state)
  where
  mapped parsed = parsed { value = transform parsed.value }

pureAt ∷ ∀ a. a → Run a
pureAt value state = Right { value, rest: state }

takeAt ∷ Run Token
takeAt state = maybe' missing taken (current state)
  where
  missing _ = failAt state "Expected a token"
  taken found = Right { value: found, rest: advance state found }

refineAt ∷ ∀ a b. (a → Either Diagnostic b) → Run a → Run b
refineAt check parser state = do
  parsed ← parser state
  value ← check parsed.value
  pure { value, rest: parsed.rest }

deferAt ∷ ∀ a. (Unit → Parser a) → Run a
deferAt later state = run (later unit) state

dispatchAt ∷ ∀ a. Array (Case a) → Parser a → Run a
dispatchAt cases fallback state =
  run (maybe fallback chosen (Array.find accepting cases)) state
  where
  text = peekText state
  accepting choice = choice.accepts text
  chosen choice = choice.parser

-- Lists are Stack-accumulated in push order, so building them is linear.
collect ∷ ∀ a. Continue → Parser a → Parser (Array a)
collect next item =
  Array.fromFoldable <$> Parser
    (foldAt next single (flip Stack.push) (run item))
  where
  single first = Stack.push first Stack.empty

-- One item per step: tailRecM runs the steps as a loop, so lists of any
-- length run in constant stack (BACKLOG E002).
foldAt ∷ ∀ a b. Continue → (a → b) → (b → a → b) → Run a → Run b
foldAt next first combine item state =
  tailRecM step { add: first, rest: state }
  where
  step pending = map (decide pending.add) (item pending.rest)
  decide add parsed = after (add parsed.value) (next parsed.rest)
  after value (Loop rest) = Loop { add: combine value, rest }
  after value (Done rest) = Done { value, rest }

separated ∷ String → Continue
separated separator state =
  if peekText state == separator then Loop (skip state) else Done state

trailing ∷ String → String → Continue
trailing separator close state
  | peekText state /= separator = Done state
  | peekText (skip state) == close = Done (skip state)
  | otherwise = Loop (skip state)

spannedAt ∷ ∀ a b. (Span → a → b) → Run a → Run b
spannedAt build parser state = map withSpan (parser state)
  where
  start = (nextSpan state).start
  withSpan parsed =
    { value: build { start, end: endOf parsed.rest } parsed.value
    , rest: parsed.rest
    }
  endOf rest = if rest.index == state.index then start else rest.lastEnd
