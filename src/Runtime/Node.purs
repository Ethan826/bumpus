-- The Node host: capability-port implementations and process primitives.
-- This is the only FFI, and it holds no command logic.
module Runtime.Node
  ( nodeHost
  , commandArguments
  , writeOutput
  , writeError
  , setExitCode
  , wireText
  ) where

import Prelude
import Data.Either (Either(..))
import Domain.Host (Host, HostFailure(..))
import Effect (Effect)
import Format.Wire (WireRecord(..))

-- Constructors the foreign code uses to answer without knowing PureScript's
-- data representation.
type Results =
  { right ∷ String → Either HostFailure String
  , io ∷ String → Either HostFailure String
  , tool ∷ String → String → Either HostFailure String
  }

type Attempt = Effect (Either HostFailure String)

foreign import commandArguments ∷ Effect (Array String)
foreign import writeOutput ∷ String → Effect Unit
foreign import writeError ∷ String → Effect Unit
foreign import setExitCode ∷ Int → Effect Unit
foreign import json ∷ ∀ fields. Record fields → String
foreign import readSourceWith ∷ Results → String → Attempt
foreign import writeTextWith ∷ Results → String → String → Attempt
foreign import buildWith ∷ Results → String → String → Attempt
foreign import runWith ∷ Results → String → Attempt

nodeHost ∷ Host Effect
nodeHost =
  { readSource: readSourceWith results
  , writeText
  , buildExecutable
  , runProgram: runWith results
  }
  where
  writeText path text = void <$> writeTextWith results path text
  buildExecutable go binary = void <$> buildWith results go binary

-- JSON is the host's technology; Format.Wire decides the fields.
wireText ∷ WireRecord → String
wireText = case _ of
  PlainWire record → json record
  SourceWire record → json record
  ToolWire record → json record

results ∷ Results
results = { right: Right, io: ioFailure, tool: toolFailure }
  where
  ioFailure text = Left (IoFailure text)
  toolFailure message command = Left (ToolFailure { message, command })
