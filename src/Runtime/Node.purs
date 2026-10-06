module Runtime.Node (launch) where

import Prelude
import Effect (Effect)
import Format.Diagnostic (Response)

foreign import launch ∷ (String → Response) → Effect Unit
