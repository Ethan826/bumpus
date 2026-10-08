module Program.Compile (compile) where

import Prelude
import Data.Either (Either)
import Domain.Syntax (Diagnostic)
import Features.Check (check)
import Features.Resolve (resolve)
import Features.Specialize (specialize)
import Features.Specialize.Unlowered (reject)
import Format.Go (emit)
import Format.Parse (parse)

-- `reject` is FN001 Task 5's temporary guard: Format.Go lowers no function
-- value or type until Task 6, which removes it.
compile ∷ String → Either Diagnostic String
compile = map emit <<< (parse >=> resolve >=> check >=> specialize >=> reject)
