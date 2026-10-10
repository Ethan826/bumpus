module Features.Check.DeferNotes (failureNotes, tailNotes) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Domain.Checked.Internal (Open(..))
import Domain.Resolved (LocalId)
import Domain.Checked.Internal as Checked
import Domain.Resolved as Resolved
import Domain.Row (Row(..))
import Data.Tuple (Tuple(..))
import Domain.Syntax (Note, NoteReason(..), Span)
import Domain.Type (Ty(..), TyRow, VarId(..))
import Domain.Type.Parts (children, rowsOf)
import Features.Check.Context (CheckEnv)
import Features.Check.Occurrence (OccurrenceId)
import Features.Check.Provenance (Consumed(..), trail)
import Features.Check.Report (crossingNotes, noteAt, originNotes)
import Features.Check.Scheme (Deferral, State, resolved)

-- A deferred expression that performs `label`: where inside it the label
-- arose, through a called function's row. A `Fail` key settled after the
-- `defer` leaves no origin at the application that brought it in; the
-- `fail` that raised it is known, so the application is the first in the
-- deferred expression whose callee is a local bound to a function
-- containing that `fail` (`whole` is the function's body, where the
-- binding is).
failureNotes
  ∷ State
  → Span
  → Checked.Expr
  → Checked.Expr
  → String
  → OccurrenceId
  → Array Note
failureNotes state span whole body label occurrence =
  brought <> originNotes span label hops <> crossingNotes label hops
  where
  hops = trail state.subst state.origins occurrence
  origins = Array.mapMaybe originOf hops
  originOf hop = hop.origin
  brought =
    if Array.any viaCall origins then []
    else maybe [] (bringing <<< spanOfOrigin) (Array.find raised origins)
  spanOfOrigin origin = origin.span
  bringing raiseSpan = maybe [] (Array.singleton <<< bring)
    (boundCall (letsContaining raiseSpan whole) body)
  raised origin = case origin.consumed of
    FailOf _ → true
    _ → false
  viaCall origin = case origin.consumed of
    CallOf _ → true
    Application → true
    _ → false
  bring application = noteAt (Checked.spanOf application)
    (FromFunctionValue label)

-- The first application in the expression whose callee is one of the locals.
boundCall ∷ Array LocalId → Checked.Expr → Maybe Checked.Expr
boundCall locals whole@(Checked.Expr expression) = case expression.node of
  Checked.Apply (Checked.Expr callee) _ | boundTo callee.node → Just whole
  _ → Array.head (Array.mapMaybe (boundCall locals) (parts whole))
  where
  boundTo = case _ of
    Checked.Local local → Array.elem local locals
    _ → false

-- The locals `let`-bound, anywhere in the expression, to a value whose
-- span contains `inner`.
letsContaining ∷ Span → Checked.Expr → Array LocalId
letsContaining inner whole@(Checked.Expr expression) =
  here <> Array.concatMap (letsContaining inner) (parts whole)
  where
  here = case expression.node of
    Checked.Block items _ → Array.mapMaybe bound items
    _ → []
  bound = case _ of
    Checked.Let (Just local) (Checked.Expr value)
      | contains value.span inner → Just local
    _ → Nothing
  contains outer within = outer.start.offset <= within.start.offset
    && within.end.offset <= outer.end.offset

-- A deferred expression that may perform any effect of a rigid row: the
-- application (or named call) whose row carried the tail, and where the
-- row is declared.
tailNotes ∷ ∀ r. CheckEnv r → State → Deferral → VarId → Array Note
tailNotes env state found variable@(VarId index) =
  [ applied, noteAt (declaration env variable) (DeclaredHere spelled) ]
  where
  spelled = "..." <> maybe "" identity (Array.index env.variables index)
  any = "any effect of " <> spelled
  applied = maybe (called env found any) application
    (firstApplication tailed state found.body)
  application expression = noteAt (Checked.spanOf expression)
    (FromFunctionValue any)
  tailed (Row _ tail) = tail == Just (Rigid variable)

-- With no application to point at, a named call in the expression, else
-- the expression.
called ∷ ∀ r. CheckEnv r → Deferral → String → Note
called env found text = maybe
  (noteAt (Checked.spanOf found.body) (FromFunctionValue text))
  named
  (firstCall found.body)
  where
  named (Tuple span (Resolved.FunctionId index)) = noteAt span
    (FromCallOf text (maybe "" _.name (Array.index env.functions index)))

firstCall ∷ Checked.Expr → Maybe (Tuple Span Resolved.FunctionId)
firstCall whole@(Checked.Expr expression) = case expression.node of
  Checked.Call id _ _ → Just (Tuple expression.span id)
  _ → Array.head (Array.mapMaybe firstCall (parts whole))

-- The first application, in evaluation order, whose function's type has a
-- row the predicate accepts.
firstApplication
  ∷ (TyRow Open → Boolean) → State → Checked.Expr → Maybe Checked.Expr
firstApplication accepts state whole@(Checked.Expr expression) =
  case expression.node of
    Checked.Apply callee _ | endsIn (Checked.typeOf callee) → Just whole
    _ → Array.head
      (Array.mapMaybe (firstApplication accepts state) (parts whole))
  where
  endsIn ty = Array.any accepts (rowsOf (resolved state.subst ty))

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
  | otherwise =
      maybe env.functionSpan parameterSpan
        (Array.find mentions parameters)
      where
      parameterSpan parameter =
        if ownRow parameter.ty then fromMaybe parameter.span parameter.rowSpan
        else parameter.span
      ownRow = case _ of
        TFun _ (Row _ tail) _ → tail == Just variable
        _ → false
      parameters = maybe [] _.parameters (Array.find named env.functions)
      named function = function.name == env.functionName
      mentions parameter = tailsIn parameter.ty
      tailsIn ty = Array.any tailed (rowsOf ty) || Array.any tailsIn
        (children ty)
      tailed (Row _ tail) = tail == Just variable
