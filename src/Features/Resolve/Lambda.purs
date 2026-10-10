module Features.Resolve.Lambda (Annotations, lambda) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Domain.Problem (DuplicateKind(..), Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax as Syntax
import Features.Resolve.Fresh (Fresh, fresh, liftEither)
import Features.Resolve.Repeated (repeated)
import Features.Resolve.Types (resolveTypeWith)

-- What an annotation may name: the declared types, and the enclosing
-- signature's variables (rigid; FN001 design §2).
type Annotations r =
  { types ∷ Array Resolved.TypeInfo
  , effects ∷ Array { name ∷ String, arity ∷ Int }
  , variables ∷ Array String
  | r
  }

type Named = { name ∷ String, span ∷ Syntax.Span }
type Bound = { param ∷ Resolved.Param, local ∷ Maybe Resolved.Local }

-- Named parameters must be distinct; then each gets its annotation and a
-- fresh LocalId in order (`_` none), and the body sees the named ones.
lambda
  ∷ ∀ r
  . Annotations r
  → Syntax.Span
  → Array Syntax.LambdaParam
  → (Array Resolved.Local → Fresh Resolved.Expr)
  → Fresh Resolved.Expr
lambda annotations span parameters body = do
  liftEither (distinct parameters)
  bound ← traverse (parameter annotations) parameters
  Resolved.Lambda span (map paramOf bound)
    <$> body (Array.mapMaybe localOf bound)
  where
  paramOf found = found.param
  localOf found = found.local

parameter
  ∷ ∀ r. Annotations r → Syntax.LambdaParam → Fresh Bound
parameter annotations syntax = boundOf <$> liftEither annotation
  <*> traverse issue syntax.name
  where
  annotation = traverse
    ( resolveTypeWith annotations.types annotations.effects
        annotations.variables
        (Just (Resolved.VarId (Array.length annotations.variables - 1)))
    )
    syntax.ty
  issue name = localNamed name <$> fresh
  boundOf ty found =
    { param: { local: map localId found, ty, span: syntax.span }
    , local: found
    }
  localId local = local.id

localNamed ∷ String → Resolved.LocalId → Resolved.Local
localNamed name id = { name, id }

-- Like a function's parameters (Features.Resolve.Types), the first named
-- parameter in source order whose name repeats is reported.
distinct ∷ Array Syntax.LambdaParam → Either Syntax.Diagnostic Unit
distinct parameters = for_ flagged report
  where
  named = Array.mapMaybe withName parameters
  withName syntax = map (namedAt syntax.span) syntax.name
  flagged = Array.zipWith withFlag (repeated (map nameOf named)) named
  nameOf found = found.name
  withFlag repeats found = { repeats, found }
  report { repeats, found }
    | repeats = Left
        ( Syntax.problemAt (Duplicate DuplicateParameter found.name)
            found.span
        )
    | otherwise = Right unit

namedAt ∷ Syntax.Span → String → Named
namedAt span name = { name, span }
