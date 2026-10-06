module Shell.CLI (main) where

import Prelude
import Data.Either (either)
import Effect (Effect)
import Sprig.Compiler (compile)
import Sprig.Model (codeName)
import Sprig.Model as Model

type WireDiagnostic = { code ∷ String, message ∷ String, span ∷ Model.Span }
type Response =
  { ok ∷ Boolean, go ∷ String, diagnostics ∷ Array WireDiagnostic }

foreign import launch ∷ (String → Response) → Effect Unit

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
