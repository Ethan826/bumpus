module Features.Check.Coverage (coverage, renderWitness) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), maybe)
import Data.String (joinWith)
import Features.Check.Usefulness
  ( Signature
  , Witness(..)
  , inhabitation
  , uncovered
  , useful
  )
import Domain.IR.Internal as IR
import Domain.Syntax (ErrorCode(..), Diagnostic, Span, problem)
import Domain.Resolved (CtorId(..), CtorInfo, Ty)

-- Functions in declaration order; within each, matches in source pre-order.
coverage ∷ IR.Program → Either Diagnostic Unit
coverage (IR.Program program) = traverse_ coverFunction program.functions
  where
  signature =
    { types: program.types
    , ctors: program.ctors
    , inhabited: inhabitation program.types program.ctors
    }
  coverFunction function = covered signature function.body

renderWitness ∷ Array CtorInfo → Witness → String
renderWitness ctors = case _ of
  WAny → "_"
  WInt value → show value
  WBool value → show value
  WCtor id fields → renderCtor ctors id fields

renderCtor ∷ Array CtorInfo → CtorId → Array Witness → String
renderCtor ctors (CtorId index) fields = name <> arguments
  where
  name = maybe "_" ctorName (Array.index ctors index)
  ctorName ctor = ctor.name
  arguments =
    if Array.null fields then ""
    else "(" <> joinWith ", " (map (renderWitness ctors) fields) <> ")"

covered ∷ Signature → IR.Expr → Either Diagnostic Unit
covered signature (IR.Expr expression) = case expression.node of
  IR.Integer _ → pure unit
  IR.Boolean _ → pure unit
  IR.Local _ → pure unit
  IR.Call _ arguments → traverse_ recur arguments
  IR.Construct _ arguments → traverse_ recur arguments
  IR.Add left right → traverse_ recur [ left, right ]
  IR.If condition yes no → traverse_ recur [ condition, yes, no ]
  IR.Match scrutinee arms → coverMatch signature expression.span scrutinee
    arms
  where
  recur = covered signature

-- A match is judged before the matches nested in its scrutinee and arms.
coverMatch
  ∷ Signature → Span → IR.Expr → Array IR.Arm → Either Diagnostic Unit
coverMatch signature span scrutinee arms = do
  redundancy signature arms
  exhaustiveness signature span (IR.typeOf scrutinee) arms
  covered signature scrutinee
  traverse_ armBody arms
  where
  armBody arm = covered signature arm.body

-- Only earlier arms can make an arm redundant.
redundancy ∷ Signature → Array IR.Arm → Either Diagnostic Unit
redundancy signature arms = maybe (pure unit) report
  (Array.findMap redundantSpan (Array.mapWithIndex earlier arms))
  where
  rows = map armRow arms
  earlier index arm = { pattern: arm.pattern, rows: Array.take index rows }
  redundantSpan candidate =
    if useful signature candidate.rows [ candidate.pattern ] then Nothing
    else Just (patternSpan candidate.pattern)
  report span = Left (problem Redundant span "Redundant match arm")

exhaustiveness
  ∷ Signature → Span → Ty → Array IR.Arm → Either Diagnostic Unit
exhaustiveness signature span ty arms = maybe (pure unit) report
  (uncovered signature (map armRow arms) [ ty ])
  where
  report witnesses = Left
    ( problem NonExhaustive span
        ( "Missing pattern: "
            <> joinWith ", " (map (renderWitness signature.ctors) witnesses)
        )
    )

armRow ∷ IR.Arm → Array IR.Pattern
armRow arm = [ arm.pattern ]

patternSpan ∷ IR.Pattern → Span
patternSpan (IR.Pattern pattern) = pattern.span
