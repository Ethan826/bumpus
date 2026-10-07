module Features.Check.Coverage (coverage) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), maybe)
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Resolved (Ty)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Features.Check.Search (firstJust)
import Features.Check.Signature (Lookup, Signature, buildSignature)
import Features.Check.Usefulness (uncovered, useful)

-- Functions in declaration order; within each, matches in source pre-order.
-- The signature is program-wide, so its failure (a table miss, which is a
-- compiler bug) has no span of its own; it surfaces at the first function
-- judged, since every function sees the same failure and the first stops.
coverage ∷ IR.Program → Either Diagnostic Unit
coverage (IR.Program program) = traverse_ coverFunction program.functions
  where
  tables = buildSignature program.types program.ctors
  coverFunction function = do
    signature ← located function.span tables
    covered signature function.body

covered ∷ Signature → IR.Expr → Either Diagnostic Unit
covered signature (IR.Expr expression) = case expression.node of
  IR.Integer _ → pure unit
  IR.Boolean _ → pure unit
  IR.Local _ → pure unit
  IR.Call _ arguments → traverse_ recur arguments
  IR.Construct _ arguments → traverse_ recur arguments
  IR.Add left right → traverse_ recur [ left, right ]
  IR.Compare _ left right → traverse_ recur [ left, right ]
  IR.If condition yes no → traverse_ recur [ condition, yes, no ]
  IR.Match scrutinee arms → coverMatch signature expression.span scrutinee
    arms
  where
  recur = covered signature

-- A match is judged before the matches nested in its scrutinee and arms.
coverMatch
  ∷ Signature → Span → IR.Expr → Array IR.Arm → Either Diagnostic Unit
coverMatch signature span scrutinee arms = do
  redundancy signature span arms
  exhaustiveness signature span (IR.typeOf scrutinee) arms
  covered signature scrutinee
  traverse_ armBody arms
  where
  armBody arm = covered signature arm.body

-- Only earlier arms can make an arm redundant; the first one is reported.
redundancy ∷ Signature → Span → Array IR.Arm → Either Diagnostic Unit
redundancy signature span arms = do
  found ← located span (firstJust judge (Array.mapWithIndex earlier arms))
  maybe (pure unit) report found
  where
  rows = map armRow arms
  earlier index arm = { pattern: arm.pattern, rows: Array.take index rows }
  judge candidate = verdict candidate <$> useful signature candidate.rows
    [ candidate.pattern ]
  verdict candidate isUseful =
    if isUseful then Nothing else Just (patternSpan candidate.pattern)
  report armSpan = Left (problemAt RedundantArm armSpan)

-- The witness vector has one entry because the match has one column.
exhaustiveness
  ∷ Signature → Span → Ty → Array IR.Arm → Either Diagnostic Unit
exhaustiveness signature span ty arms = do
  found ← located span (uncovered signature (map armRow arms) [ ty ])
  maybe (pure unit) report found
  where
  report witnesses = Left (problemAt (single witnesses) span)
  single = case _ of
    [ witness ] → NonExhaustive witness
    _ → Internal "Expected one missing pattern"

-- Places a table failure, which is a compiler bug, at the span being judged.
located ∷ ∀ a. Span → Lookup a → Either Diagnostic a
located span = either failure Right
  where
  failure problem = Left (problemAt problem span)

armRow ∷ IR.Arm → Array IR.Pattern
armRow arm = [ arm.pattern ]

patternSpan ∷ IR.Pattern → Span
patternSpan (IR.Pattern pattern) = pattern.span
