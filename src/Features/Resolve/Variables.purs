module Features.Resolve.Variables
  ( signatureVariables
  , uniqueTypeParameters
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Domain.Problem (DuplicateKind(..), Problem(..))
import Domain.Syntax as Syntax
import Features.Resolve.Repeated (laterRepeat)

-- A function's type variables are implicitly quantified over its whole
-- signature: every lowercase name in its parameter and result types, in
-- first-occurrence order, so `VarId i` is the i-th of them.
signatureVariables ∷ Array Syntax.TypeRef → Array String
signatureVariables references =
  Array.nub (Array.concatMap occurrences references)

-- A type parameter that repeats an earlier one of its declaration is
-- reported at the repetition, declaration by declaration.
uniqueTypeParameters ∷ Array Syntax.TypeDecl → Either Syntax.Diagnostic Unit
uniqueTypeParameters = traverse_ uniqueIn
  where
  uniqueIn declaration = traverse_ duplicate
    ( laterRepeat (map name declaration.parameters)
        >>= Array.index declaration.parameters
    )
  name parameter = parameter.name
  duplicate parameter = Left
    ( Syntax.problemAt (Duplicate DuplicateTypeParameter parameter.name)
        parameter.span
    )

occurrences ∷ Syntax.TypeRef → Array String
occurrences = case _ of
  Syntax.IntRef _ → []
  Syntax.BoolRef _ → []
  Syntax.VarRef _ name → [ name ]
  Syntax.NamedRef _ _ arguments → Array.concatMap occurrences arguments
