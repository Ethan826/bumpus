module Features.Check.Arms (MatchEnv, Infer, checkMatch) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty)
import Features.Check.Match (PatternEnv, Typed, patternAgainst)
import Features.Check.Require (require)
import Features.Check.Scheme (State, Threaded, threadAll)

-- Open rows let Features.Check pass its own environment through unchanged.
type MatchEnv r = PatternEnv (locals ∷ Array Typed | r)

-- Arms' own row: Features.Check.Infer's `infer` reaches here through
-- checkMatch with its whole Env, of which matching needs the pattern
-- tables, the variables' names and the locals. (Call.Infer has its own row
-- for the same reason; neither module may import Infer, which imports both.)
type Infer r =
  MatchEnv r → State → Resolved.Expr → Either Diagnostic (Threaded Checked.Expr)

-- Each arm is checked as pattern, then body, then against the first arm.
checkMatch
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → State
  → Span
  → Resolved.Expr
  → Array Resolved.Arm
  → Either Diagnostic (Threaded Checked.Expr)
checkMatch infer env state span scrutinee arms = do
  head ← infer env state scrutinee
  maybe' empty (checkArms infer env span head) (Array.uncons arms)
  where
  empty _ = Left (problemAt (Internal "Empty resolved match") span)

checkArms
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → Span
  → Threaded Checked.Expr
  → { head ∷ Resolved.Arm, tail ∷ Array Resolved.Arm }
  → Either Diagnostic (Threaded Checked.Expr)
checkArms infer env span head split = do
  first ← checkArm infer env head.state scrutineeType split.head
  rest ← threadAll (laterArm infer env scrutineeType first.value) first.state
    split.tail
  pure
    { value: Checked.Expr
        { ty: Checked.typeOf first.value.body
        , span
        , node: Checked.Match head.value (Array.cons first.value rest.value)
        }
    , state: rest.state
    }
  where
  scrutineeType = Checked.typeOf head.value

laterArm
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → Ty Open
  → Checked.Arm
  → State
  → Resolved.Arm
  → Either Diagnostic (Threaded Checked.Arm)
laterArm infer env scrutineeType first state arm = do
  checked ← checkArm infer env state scrutineeType arm
  unified ← require env checked.state (Checked.typeOf first.body)
    checked.value.body
  pure { value: checked.value, state: unified }

checkArm
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → State
  → Ty Open
  → Resolved.Arm
  → Either Diagnostic (Threaded Checked.Arm)
checkArm infer env state ty arm = do
  matched ← patternAgainst env state ty arm.pattern
  body ← infer (env { locals = env.locals <> matched.value.locals })
    matched.state
    arm.body
  pure
    { value:
        { pattern: matched.value.pattern, body: body.value, span: arm.span }
    , state: body.state
    }
