module Features.Specialize.Body (fillFunction) where

import Prelude
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Resolved (FunctionId(..))
import Domain.Syntax (Span)
import Domain.Type (Ty)
import Features.Specialize.Copy (modify)
import Features.Specialize.Keys
  ( Env
  , Specializing
  , Work
  , called
  , ctorAt
  , internal
  )
import Features.Specialize.Lower (lowerType)

-- One key's copy of a function: its declaration with every type at the
-- key's arguments and every call and constructor renumbered.
type Scope = { env ∷ Env, arguments ∷ Array IR.Ty }

-- The signature first, then the body in pre-order (design §6): an
-- expression's type, then a call's instantiation and callee, then its
-- parts left to right; an arm's pattern before its body.
fillFunction ∷ Env → Work → Specializing Unit
fillFunction env work = maybe'
  (internal "Invalid function id" work.span)
  copied
  (Array.index env.functions work.declaration)
  where
  scope = { env, arguments: work.arguments }
  copied declared = do
    parameters ← traverse (lowered scope declared.span) declared.parameters
    result ← lowered scope declared.span declared.result
    body ← expression scope declared.body
    modify (inserted declared { parameters, result, body })
  inserted declared copy state = state
    { functions = Map.insert work.output
        { id: FunctionId work.output
        , name: declared.name
        , parameters: copy.parameters
        , result: copy.result
        , body: copy.body
        , span: declared.span
        }
        state.functions
    }

lowered ∷ Scope → Span → Ty Checked.Open → Specializing IR.Ty
lowered scope = lowerType scope.env scope.arguments

expression ∷ Scope → Checked.Expr → Specializing IR.Expr
expression scope (Checked.Expr checked) = do
  ty ← lowered scope checked.span checked.ty
  node ← copyNode scope checked.span ty checked.node
  pure (IR.Expr { ty, span: checked.span, node })

-- A construction's instantiation is its own type's arguments, numbered
-- with that type just before, so only a call lowers its instantiation.
copyNode ∷ Scope → Span → IR.Ty → Checked.Node → Specializing IR.Node
copyNode scope span ty = case _ of
  Checked.Integer value → pure (IR.Integer value)
  Checked.Boolean value → pure (IR.Boolean value)
  Checked.Local id → pure (IR.Local id)
  Checked.Call id instantiation arguments → copyCall scope span id
    instantiation
    arguments
  Checked.Construct id _ arguments → IR.Construct
    <$> ctorAt scope.env span ty id
    <*> each arguments
  Checked.Add left right → IR.Add <$> recur left <*> recur right
  Checked.Compare operator left right → IR.Compare operator <$> recur left
    <*> recur right
  Checked.If condition yes no → IR.If <$> recur condition <*> recur yes
    <*> recur no
  Checked.Match scrutinee arms → IR.Match <$> recur scrutinee
    <*> traverse (arm scope) arms
  -- Function values are copied from FN001 Task 5.
  Checked.FunctionRef _ _ → unlowered
  Checked.CtorRef _ _ → unlowered
  Checked.Apply _ _ → unlowered
  Checked.Lambda _ _ → unlowered
  Checked.Pipe _ _ → unlowered
  where
  unlowered = internal "unlowered function" span unit
  recur = expression scope
  each = traverse recur

-- A call lowers its instantiation, then names its callee's copy at those
-- arguments, then copies its arguments.
copyCall
  ∷ Scope
  → Span
  → FunctionId
  → Array (Ty Checked.Open)
  → Array Checked.Expr
  → Specializing IR.Node
copyCall scope span id instantiation arguments = do
  types ← traverse (lowered scope span) instantiation
  callee ← called scope.env span id types
  IR.Call callee <$> traverse (expression scope) arguments

arm ∷ Scope → Checked.Arm → Specializing IR.Arm
arm scope checked = do
  pattern ← copyPattern scope checked.pattern
  body ← expression scope checked.body
  pure { pattern, body, span: checked.span }

copyPattern ∷ Scope → Checked.Pattern → Specializing IR.Pattern
copyPattern scope (Checked.Pattern checked) = do
  ty ← lowered scope checked.span checked.ty
  shape ← copyShape scope checked.span ty checked.shape
  pure (IR.Pattern { ty, span: checked.span, shape })

copyShape ∷ Scope → Span → IR.Ty → Checked.Shape → Specializing IR.Shape
copyShape scope span ty = case _ of
  Checked.Wildcard → pure IR.Wildcard
  Checked.Bind id → pure (IR.Bind id)
  Checked.IntLit value → pure (IR.IntLit value)
  Checked.BoolLit value → pure (IR.BoolLit value)
  Checked.Ctor id fields → IR.Ctor <$> ctorAt scope.env span ty id
    <*> traverse (copyPattern scope) fields
