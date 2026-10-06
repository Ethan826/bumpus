module Sprig.Check (check, CheckedProgram) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Data.Traversable (traverse)
import Sprig.IR.Internal as IR
import Sprig.Model (ErrorCode(..), Diagnostic, Span, Ty(..), problem)
import Sprig.Resolved as R

type CheckedProgram = IR.Program

check ∷ R.Program → Either Diagnostic CheckedProgram
check program = do
  functions ← traverse (checkFunction program.functions) program.functions
  pure (IR.Program { functions, entry: program.entry })

checkFunction
  ∷ Array R.FunctionDecl → R.FunctionDecl → Either Diagnostic IR.FunctionDecl
checkFunction globals function = do
  body ← infer globals function.parameters function.body
  require function.result body
  pure
    { id: function.id
    , parameters: map parameterType function.parameters
    , result: function.result
    , body
    , span: function.span
    }
  where
  parameterType parameter = parameter.ty

require ∷ Ty → IR.Expr → Either Diagnostic Unit
require expected actual =
  if expected == IR.typeOf actual then Right unit
  else Left
    ( problem TypeMismatch (IR.spanOf actual)
        ("Expected " <> show expected <> ", found " <> show (IR.typeOf actual))
    )

infer
  ∷ Array R.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → R.Expr
  → Either Diagnostic IR.Expr
infer globals locals expression = case expression of
  R.Integer span value → pure
    (IR.Expr { ty: TInt, span, node: IR.Integer value })
  R.Boolean span value → pure
    (IR.Expr { ty: TBool, span, node: IR.Boolean value })
  R.Local span id → checkLocal locals span id
  R.Call span id arguments → checkCall globals locals span id arguments
  R.Add span left right → checkAddition globals locals span left right
  R.If span condition yes no → checkConditional globals locals span condition
    yes
    no

checkAddition
  ∷ Array R.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → R.Expr
  → R.Expr
  → Either Diagnostic IR.Expr
checkAddition globals locals span left right = do
  first ← infer globals locals left
  second ← infer globals locals right
  require TInt first
  require TInt second
  pure (IR.Expr { ty: TInt, span, node: IR.Add first second })

checkConditional
  ∷ Array R.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → R.Expr
  → R.Expr
  → R.Expr
  → Either Diagnostic IR.Expr
checkConditional globals locals span condition yes no = do
  predicate ← infer globals locals condition
  require TBool predicate
  first ← infer globals locals yes
  second ← infer globals locals no
  require (IR.typeOf first) second
  pure
    (IR.Expr { ty: IR.typeOf first, span, node: IR.If predicate first second })

checkLocal
  ∷ Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → R.LocalId
  → Either Diagnostic IR.Expr
checkLocal locals span id@(R.LocalId index) = maybe missing found
  (Array.index locals index)
  where
  missing = Left (problem InternalError span "Invalid resolved local")
  found parameter = pure (IR.Expr { ty: parameter.ty, span, node: IR.Local id })

checkCall
  ∷ Array R.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → R.FunctionId
  → Array R.Expr
  → Either Diagnostic IR.Expr
checkCall globals locals span id@(R.FunctionId index) arguments = maybe' missing
  found
  (Array.index globals index)
  where
  missing _ = Left (problem InternalError span "Invalid resolved function")
  found function = do
    when (Array.length arguments /= Array.length function.parameters)
      (Left (problem ArityMismatch span "Wrong number of arguments"))
    checked ← traverse (infer globals locals) arguments
    _ ← traverse checkArgument
      (Array.zipWith argumentPair function.parameters checked)
    pure (IR.Expr { ty: function.result, span, node: IR.Call id checked })
  argumentPair expected actual = { expected, actual }
  checkArgument pair = require pair.expected.ty pair.actual
