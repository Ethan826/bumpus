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
import Features.Specialize.Copy (modify)
import Features.Specialize.Keys (Env, Specializing, Work, internal)
import Features.Specialize.Values
  ( Scope
  , callee
  , lambda
  , ownerCtor
  , typed
  )

-- One key's copy of a function: its declaration with every type at the
-- key's arguments and every reference and constructor renumbered.
-- The signature first, then the body in pre-order (design §6): an
-- expression's type, then a reference's instantiation and callee, then
-- its parts left to right; an arm's pattern before its body; a lambda's
-- parameters before its body.
fillFunction ∷ Env → Work → Specializing Unit
fillFunction env work = maybe'
  (internal "Invalid function id" work.span)
  copied
  (Array.index env.functions work.declaration)
  where
  scope = { env, arguments: work.arguments }
  copied declared = do
    parameters ← traverse (typed scope declared.span) declared.parameters
    result ← typed scope declared.span declared.result
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

expression ∷ Scope → Checked.Expr → Specializing IR.Expr
expression scope (Checked.Expr checked) = do
  ty ← typed scope checked.span checked.ty
  node ← copyNode scope checked.span ty checked.node
  pure (IR.Expr { ty, span: checked.span, node })

-- A construction's instantiation is its own type's arguments, numbered
-- with that type just before, so only a function reference lowers its
-- instantiation. Every arm delegates (BACKLOG E003).
copyNode ∷ Scope → Span → IR.Ty → Checked.Node → Specializing IR.Node
copyNode scope span ty = case _ of
  Checked.Integer value → pure (IR.Integer value)
  Checked.Boolean value → pure (IR.Boolean value)
  Checked.Local id → pure (IR.Local id)
  Checked.Call id instantiation arguments → IR.Call
    <$> callee scope span id instantiation
    <*> each arguments
  Checked.Construct id _ arguments → IR.Construct
    <$> ownerCtor scope span ty id
    <*> each arguments
  Checked.Add left right → IR.Add <$> recur left <*> recur right
  Checked.Compare operator left right → IR.Compare operator <$> recur left
    <*> recur right
  Checked.If condition yes no → IR.If <$> recur condition <*> recur yes
    <*> recur no
  Checked.Match scrutinee arms → IR.Match <$> recur scrutinee
    <*> traverse (arm scope) arms
  Checked.FunctionRef id instantiation → IR.FunctionRef
    <$> callee scope span id instantiation
  Checked.CtorRef id _ → IR.CtorRef <$> ownerCtor scope span ty id
  Checked.Apply applied arguments → IR.Apply <$> recur applied
    <*> each arguments
  Checked.Lambda parameters body → lambda scope recur span parameters body
  Checked.Pipe left right → IR.Pipe <$> recur left <*> recur right
  where
  recur = expression scope
  each = traverse recur

arm ∷ Scope → Checked.Arm → Specializing IR.Arm
arm scope checked = do
  pattern ← copyPattern scope checked.pattern
  body ← expression scope checked.body
  pure { pattern, body, span: checked.span }

copyPattern ∷ Scope → Checked.Pattern → Specializing IR.Pattern
copyPattern scope (Checked.Pattern checked) = do
  ty ← typed scope checked.span checked.ty
  shape ← copyShape scope checked.span ty checked.shape
  pure (IR.Pattern { ty, span: checked.span, shape })

copyShape ∷ Scope → Span → IR.Ty → Checked.Shape → Specializing IR.Shape
copyShape scope span ty = case _ of
  Checked.Wildcard → pure IR.Wildcard
  Checked.Bind id → pure (IR.Bind id)
  Checked.IntLit value → pure (IR.IntLit value)
  Checked.BoolLit value → pure (IR.BoolLit value)
  Checked.Ctor id fields → IR.Ctor <$> ownerCtor scope span ty id
    <*> traverse (copyPattern scope) fields
