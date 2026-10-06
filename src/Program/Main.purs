module Program.Main (main) where

import Prelude
import Data.Either (either)
import Effect (Effect)
import Format.Diagnostic (Response, wire)
import Program.Compile (compile)
import Runtime.Node (launch)

main ∷ Effect Unit
main = launch respond

respond ∷ String → Response
respond source = either failed succeeded (compile source)
  where
  failed diagnostic = { ok: false, go: "", diagnostics: [ wire diagnostic ] }
  succeeded go = { ok: true, go, diagnostics: [] }
