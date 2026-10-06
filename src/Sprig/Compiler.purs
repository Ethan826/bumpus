module Sprig.Compiler (compile) where

import Prelude
import Data.Either (Either)
import Sprig.Check (check)
import Sprig.Go (emit)
import Sprig.Model (Diagnostic)
import Sprig.Parse (parse)
import Sprig.Resolve (resolve)

compile ∷ String → Either Diagnostic String
compile source = emit <$> (parse source >>= resolve >>= check)
