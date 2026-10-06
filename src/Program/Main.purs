module Program.Main (main) where

import Prelude
import Data.Foldable (traverse_)
import Effect (Effect)
import Program.Command (command)
import Runtime.Node
  ( commandArguments
  , nodeHost
  , setExitCode
  , wireText
  , writeError
  , writeOutput
  )

-- Wires the Node host into the commands, then writes the outcome.
main ∷ Effect Unit
main = do
  outcome ← command nodeHost =<< commandArguments
  writeOutput outcome.stdout
  traverse_ (writeError <<< wireText) outcome.stderr
  setExitCode outcome.status
