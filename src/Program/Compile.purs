module Program.Compile (compile) where

import Prelude
import Data.Either (Either)
import Domain.Syntax (Diagnostic)
import Features.Check (check)
import Features.Check.Unlowered (reject)
import Features.Resolve (resolve)
import Features.Specialize (specialize)
import Format.Go (emit)
import Format.Parse (parse)

compile ∷ String → Either Diagnostic String
compile = map emit <<< (parse >=> resolve >=> check >=> guarded >=> specialize)
  where
  guarded checked = checked <$ reject checked
