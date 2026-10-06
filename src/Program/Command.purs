-- CLI commands over capability ports. The monad is abstract, so tests run
-- every command against fake hosts without processes.
module Program.Command (Outcome, command) where

import Prelude
import Data.Either (Either, either)
import Data.Maybe (Maybe(..))
import Domain.Host (Host, HostFailure)
import Domain.Syntax (Diagnostic)
import Format.Arguments (Invocation(..), invocation)
import Format.Wire (WireRecord, failureRecord, sourceRecord, usageRecord)
import Program.Compile (compile)

type Outcome = { status ∷ Int, stdout ∷ String, stderr ∷ Maybe WireRecord }

usageStatus ∷ Int
usageStatus = 2

failureStatus ∷ Int
failureStatus = 1

command ∷ ∀ m. Monad m ⇒ Host m → Array String → m Outcome
command host arguments =
  either usageOutcome (perform host) (invocation arguments)
  where
  usageOutcome text = pure (failed usageStatus (usageRecord text))

perform ∷ ∀ m. Monad m ⇒ Host m → Invocation → m Outcome
perform host = case _ of
  Emit input output → translated host input (emitTo output)
  Build input output → translated host input (buildTo output)
  Run input → translated host input runGo
  where
  emitTo output go = completed <$> host.writeText output go
  buildTo output go = completed <$> host.buildExecutable go output
  runGo go = printed <$> host.runProgram go

-- Reads and compiles the input, then hands the Go text to the next step.
translated
  ∷ ∀ m. Monad m ⇒ Host m → String → (String → m Outcome) → m Outcome
translated host input next =
  host.readSource input >>= either (pure <<< hostFailed) compiled
  where
  compiled source = either (pure <<< rejected input) next (compile source)

rejected ∷ String → Diagnostic → Outcome
rejected input diagnostic =
  failed failureStatus (sourceRecord input diagnostic)

completed ∷ Either HostFailure Unit → Outcome
completed = either hostFailed (const (succeeded ""))

printed ∷ Either HostFailure String → Outcome
printed = either hostFailed succeeded

hostFailed ∷ HostFailure → Outcome
hostFailed failure = failed failureStatus (failureRecord failure)

succeeded ∷ String → Outcome
succeeded stdout = { status: 0, stdout, stderr: Nothing }

failed ∷ Int → WireRecord → Outcome
failed status record = { status, stdout: "", stderr: Just record }
