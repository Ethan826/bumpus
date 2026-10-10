module Features.Check.DeferNotes (failureNotes, tailNotes) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Row (Row(..))
import Domain.Syntax (Note, NoteReason(..), Span)
import Domain.Type (VarId(..))
import Domain.Type.Parts (children, rowsOf)
import Features.Check.Context (CheckEnv)
import Features.Check.Occurrence (OccurrenceId)
import Features.Check.Provenance (trail)
import Features.Check.Report (crossingNotes, noteAt, originNotes)
import Features.Check.Scheme (Deferral, State, resolved)

-- A deferred expression that performs `label`: where inside it the label
-- arose, through a called function's row or a `Fail` key settled later.
failureNotes ∷ State → Span → String → OccurrenceId → Array Note
failureNotes state span label occurrence =
  originNotes span label hops <> crossingNotes label hops
  where
  hops = trail state.subst state.origins occurrence

-- A deferred expression that may perform any effect of a rigid row: the
-- application whose row carried the tail, and where the row is declared.
tailNotes ∷ ∀ r. CheckEnv r → State → Deferral → VarId → Array Note
tailNotes env state found variable@(VarId index) =
  [ noteAt applied (FromFunctionValue ("any effect of " <> spelled))
  , noteAt declared (DeclaredHere spelled)
  ]
  where
  spelled = "..." <> maybe "" identity (Array.index env.variables index)
  applied = maybe (Checked.spanOf found.body) Checked.spanOf
    (carrying state (Rigid variable) found.body)
  declared = declaration env variable

-- The first application, in evaluation order, whose function's row ends in
-- the rigid variable.
carrying ∷ State → Open → Checked.Expr → Maybe Checked.Expr
carrying state rigid whole@(Checked.Expr expression) = case expression.node of
  Checked.Apply callee _ | endsIn (Checked.typeOf callee) → Just whole
  _ → Array.head (Array.mapMaybe (carrying state rigid) (parts whole))
  where
  endsIn ty = Array.any tailed (rowsOf (resolved state.subst ty))
  tailed (Row _ tail) = tail == Just rigid

-- An expression's direct parts, in evaluation order.
parts ∷ Checked.Expr → Array Checked.Expr
parts (Checked.Expr expression) = case expression.node of
  Checked.Call _ _ arguments → arguments
  Checked.Construct _ _ arguments → arguments
  Checked.Add left right → [ left, right ]
  Checked.Compare _ left right → [ left, right ]
  Checked.If condition yes no → [ condition, yes, no ]
  Checked.Match scrutinee arms → Array.cons scrutinee (map armBody arms)
  Checked.Apply callee arguments → Array.cons callee arguments
  Checked.Lambda _ body → [ body ]
  Checked.Pipe left right → [ left, right ]
  Checked.Print value → [ value ]
  Checked.Crash value → [ value ]
  Checked.Perform _ _ _ arguments → arguments
  Checked.Handler _ _ clauses → map handlerBody clauses
  Checked.With handler body → [ handler, body ]
  Checked.Handle body clauses → Array.cons body (map failureBody clauses)
  Checked.Fail value → [ value ]
  Checked.Block items value → Checked.blockParts items value
  _ → []
  where
  armBody arm = arm.body
  handlerBody clause = clause.body
  failureBody clause = clause.body

-- `...` is declared by the enclosing signature, `...e` where the
-- signature first mentions it: the first parameter whose type has it as a
-- row tail.
declaration ∷ ∀ r. CheckEnv r → VarId → Span
declaration env variable@(VarId index)
  | Array.index env.variables index == Just "" = env.functionSpan
  | otherwise = maybe env.functionSpan _.span (Array.find mentions parameters)
      where
      parameters = maybe [] _.parameters
        (Array.find named env.functions)
      named function = function.name == env.functionName
      mentions parameter = tailsIn parameter.ty
      tailsIn ty = Array.any tailed (rowsOf ty) || Array.any tailsIn
        (children ty)
      tailed (Row _ tail) = tail == Just variable
