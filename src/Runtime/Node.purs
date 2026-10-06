module Runtime.Node (WireDiagnostic, Response, launch) where

import Prelude
import Domain.Syntax (Span)
import Effect (Effect)

type WireDiagnostic = { code ∷ String, message ∷ String, span ∷ Span }
type Response =
  { ok ∷ Boolean, go ∷ String, diagnostics ∷ Array WireDiagnostic }

foreign import launch ∷ (String → Response) → Effect Unit
