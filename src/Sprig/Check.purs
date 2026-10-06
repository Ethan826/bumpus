module Sprig.Check (check, CheckedProgram) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Sprig.IR.Internal as IR
import Sprig.Model (ErrorCode(..), Diagnostic, Span, Ty(..), problem)
import Sprig.Resolved as Resolved

type CheckedProgram = IR.Program

check ∷ Resolved.Program → Either Diagnostic CheckedProgram
check program = do
  functions ← traverse checkDefinition program.functions
  pure (IR.Program { functions, entry: program.entry })
  where
  checkDefinition definition = checkFunction program.functions definition

checkFunction
  ∷ Array Resolved.FunctionDecl
  → Resolved.FunctionDecl
  → Either Diagnostic IR.FunctionDecl
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
  else mismatch
  where
  mismatch = Left
    ( problem TypeMismatch (IR.spanOf actual)
        ( "Expected " <> show expected <> ", found " <> show
            (IR.typeOf actual)
        )
    )

infer
  ∷ Array Resolved.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Resolved.Expr
  → Either Diagnostic IR.Expr
infer globals locals expression = case expression of
  Resolved.Integer span value → checkedInteger span value
  Resolved.Boolean span value → checkedBoolean span value
  Resolved.Local span id → checkLocal locals span id
  Resolved.Call span id arguments → checkCall globals locals span id arguments
  Resolved.Add span left right → checkAddition globals locals span left right
  Resolved.If span condition yes no → checkConditional globals locals span
    condition
    yes
    no

checkedInteger ∷ Span → Int → Either Diagnostic IR.Expr
checkedInteger span value = pure
  (IR.Expr { ty: TInt, span, node: IR.Integer value })

checkedBoolean ∷ Span → Boolean → Either Diagnostic IR.Expr
checkedBoolean span value = pure
  (IR.Expr { ty: TBool, span, node: IR.Boolean value })

checkAddition
  ∷ Array Resolved.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → Resolved.Expr
  → Resolved.Expr
  → Either Diagnostic IR.Expr
checkAddition globals locals span left right = do
  first ← infer globals locals left
  second ← infer globals locals right
  require TInt first
  require TInt second
  pure (IR.Expr { ty: TInt, span, node: IR.Add first second })

checkConditional
  ∷ Array Resolved.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → Resolved.Expr
  → Resolved.Expr
  → Resolved.Expr
  → Either Diagnostic IR.Expr
checkConditional globals locals span condition yes no = do
  predicate ← infer globals locals condition
  require TBool predicate
  first ← infer globals locals yes
  second ← infer globals locals no
  require (IR.typeOf first) second
  pure
    ( IR.Expr
        { ty: IR.typeOf first
        , span
        , node: IR.If predicate first second
        }
    )

checkLocal
  ∷ Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → Resolved.LocalId
  → Either Diagnostic IR.Expr
checkLocal locals span id@(Resolved.LocalId index) = maybe' missing found
  (Array.index locals index)
  where
  missing _ = Left (problem InternalError span "Invalid resolved local")
  found parameter = pure
    (IR.Expr { ty: parameter.ty, span, node: IR.Local id })

checkCall
  ∷ Array Resolved.FunctionDecl
  → Array { name ∷ String, ty ∷ Ty, span ∷ Span }
  → Span
  → Resolved.FunctionId
  → Array Resolved.Expr
  → Either Diagnostic IR.Expr
checkCall globals locals span id@(Resolved.FunctionId index) arguments = maybe'
  missing
  found
  (Array.index globals index)
  where
  missing _ = Left (problem InternalError span "Invalid resolved function")
  found function = do
    when (Array.length arguments /= Array.length function.parameters)
      (Left (problem ArityMismatch span "Wrong number of arguments"))
    checked ← traverse checkExpression arguments
    _ ← traverse checkArgument
      (Array.zipWith argumentPair function.parameters checked)
    pure
      ( IR.Expr
          { ty: function.result, span, node: IR.Call id checked }
      )
  checkExpression argument = infer globals locals argument
  argumentPair expected actual = { expected, actual }
  checkArgument pair = require pair.expected.ty pair.actual
