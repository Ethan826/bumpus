module Features.Specialize (specialize) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorInfo)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), ground)

-- Lowers the checked IR to the monomorphic IR Go generation reads. Until
-- P001 adds type variables every checked program is monomorphic, so this
-- copies it unchanged: a variable or a type argument cannot occur, and one
-- that does is a compiler bug, E_INTERNAL at the place that holds it.
specialize ∷ Checked.Program → Either Diagnostic IR.Program
specialize (Checked.Program program) = do
  ctors ← traverse ctorInfo program.ctors
  functions ← traverse function program.functions
  pure
    ( IR.Program
        { types: program.types, ctors, functions, entry: program.entry }
    )

ctorInfo ∷ CtorInfo → Either Diagnostic IR.CtorInfo
ctorInfo ctor = withFields <$> traverse (monomorphic ctor.span) ctor.fields
  where
  withFields fields = ctor { fields = fields }

function ∷ Checked.FunctionDecl → Either Diagnostic IR.FunctionDecl
function declaration = do
  parameters ← traverse (monomorphic span) declaration.parameters
  result ← monomorphic span declaration.result
  body ← expression declaration.body
  pure { id: declaration.id, parameters, result, body, span }
  where
  span = declaration.span

expression ∷ Checked.Expr → Either Diagnostic IR.Expr
expression (Checked.Expr checked) = do
  ty ← monomorphic checked.span checked.ty
  node ← lowerNode checked.span checked.node
  pure (IR.Expr { ty, span: checked.span, node })

lowerNode ∷ Span → Checked.Node → Either Diagnostic IR.Node
lowerNode span = case _ of
  Checked.Integer value → pure (IR.Integer value)
  Checked.Boolean value → pure (IR.Boolean value)
  Checked.Local id → pure (IR.Local id)
  Checked.Call id types arguments → IR.Call id <$> applied types arguments
  Checked.Construct id types arguments → IR.Construct id <$> applied types
    arguments
  Checked.Add left right → IR.Add <$> expression left <*> expression right
  Checked.Compare operator left right → IR.Compare operator
    <$> expression left
    <*> expression right
  Checked.If condition yes no → IR.If <$> expression condition
    <*> expression yes
    <*> expression no
  Checked.Match scrutinee arms → IR.Match <$> expression scrutinee
    <*> traverse arm arms
  where
  applied types arguments =
    if Array.null types then traverse expression arguments
    else Left (unspecialized span)

arm ∷ Checked.Arm → Either Diagnostic IR.Arm
arm checked = do
  pattern ← lowerPattern checked.pattern
  body ← expression checked.body
  pure { pattern, body, span: checked.span }

lowerPattern ∷ Checked.Pattern → Either Diagnostic IR.Pattern
lowerPattern (Checked.Pattern checked) = do
  ty ← monomorphic checked.span checked.ty
  shape ← lowerShape checked.shape
  pure (IR.Pattern { ty, span: checked.span, shape })

lowerShape ∷ Checked.Shape → Either Diagnostic IR.Shape
lowerShape = case _ of
  Checked.Wildcard → pure IR.Wildcard
  Checked.Bind id → pure (IR.Bind id)
  Checked.IntLit value → pure (IR.IntLit value)
  Checked.BoolLit value → pure (IR.BoolLit value)
  Checked.Ctor id fields → IR.Ctor id <$> traverse lowerPattern fields

-- A ground type with no type argument; every other type is unspecialized.
monomorphic ∷ ∀ v. Span → Ty v → Either Diagnostic IR.Ty
monomorphic span ty = maybe' missing lowered (ground ty)
  where
  missing _ = Left (unspecialized span)
  lowered = case _ of
    TInt → Right IR.TInt
    TBool → Right IR.TBool
    TData id [] → Right (IR.TData id)
    TData _ _ → Left (unspecialized span)
    TVar variable → absurd variable

unspecialized ∷ Span → Diagnostic
unspecialized = problemAt (Internal "unspecialized type")
