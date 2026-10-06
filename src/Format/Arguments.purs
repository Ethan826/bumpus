module Format.Arguments (Invocation(..), invocation, usage) where

import Prelude
import Data.Either (Either(..))
import Data.String as String

data Invocation = Emit String String | Build String String | Run String

usage ∷ String
usage = "sprig emit|build INPUT OUTPUT; sprig run INPUT"

-- An empty input or output counts as missing, as in the original Node CLI,
-- so `run INPUT ""` is a run and `emit INPUT ""` is a usage error.
invocation ∷ Array String → Either String Invocation
invocation = case _ of
  [ mode, input ] | given input → withoutOutput mode input
  [ mode, input, output ]
    | given input && given output → withOutput mode input output
    | given input → withoutOutput mode input
  _ → Left usage

given ∷ String → Boolean
given text = not (String.null text)

withoutOutput ∷ String → String → Either String Invocation
withoutOutput mode input = case mode of
  "run" → Right (Run input)
  _ → Left usage

withOutput ∷ String → String → String → Either String Invocation
withOutput mode input output = case mode of
  "emit" → Right (Emit input output)
  "build" → Right (Build input output)
  _ → Left usage
