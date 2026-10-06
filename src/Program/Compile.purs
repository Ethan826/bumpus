module Program.Compile (compile) where

import Prelude
import Data.Either (Either)
import Features.Check (check)
import Format.Go (emit)
import Domain.Syntax (Diagnostic)
import Format.Parse (parse)
import Features.Resolve (resolve)

compile ∷ String → Either Diagnostic String
compile source = emit <$> (parse source >>= resolve >>= check)
