-- Capability ports. The monad stays abstract, so Domain needs no Effect and
-- tests can pass fake records in place of the Node host.
module Domain.Host (HostFailure(..), Host) where

import Data.Either (Either)
import Prelude (Unit)

data HostFailure
  = IoFailure String
  | ToolFailure { message ∷ String, command ∷ String }

-- `buildExecutable goSource binaryPath` and `runProgram goSource` own their
-- temporary directory and remove it before returning.
type Host m =
  { readSource ∷ String → m (Either HostFailure String)
  , writeText ∷ String → String → m (Either HostFailure Unit)
  , buildExecutable ∷ String → String → m (Either HostFailure Unit)
  , runProgram ∷ String → m (Either HostFailure String)
  }
