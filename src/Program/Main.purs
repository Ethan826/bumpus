module Program.Main (main) where

import Prelude
import Data.Either (either)
import Effect (Effect)
import Format.Diagnostic (Response, codeName)
import Program.Compile (compile)
import Runtime.Node (launch)

main ∷ Effect Unit
main = launch respond

respond ∷ String → Response
respond source = either failed succeeded (compile source)
  where
  failed diagnostic =
    { ok: false
    , go: ""
    , diagnostics: [ diagnostic { code = codeName diagnostic.code } ]
    }
  succeeded go = { ok: true, go, diagnostics: [] }
