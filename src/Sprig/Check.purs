module Sprig.Check (check, CheckedProgram) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Sprig.IR.Internal as IR
import Sprig.Model (ErrorCode(..), Diagnostic, Span, problem)
import Sprig.Resolved (Ty(..), describe)
import Sprig.Resolved as Resolved

type CheckedProgram = IR.Program

type Env =
  { functions ∷ Array Resolved.FunctionDecl
  , types ∷ Array Resolved.TypeInfo
  , ctors ∷ Array Resolved.CtorInfo
  , locals ∷ Array { id ∷ Resolved.LocalId, ty ∷ Ty }
  }

check ∷ Resolved.Program → Either Diagnostic CheckedProgram
check program = do
  functions ← traverse checkDefinition program.functions
  pure
    ( IR.Program
        { types: program.types
        , ctors: program.ctors
        , functions
        , entry: program.entry
        }
    )
  where
  checkDefinition definition = checkFunction (environment program) definition

environment ∷ Resolved.Program → Env
environment program =
  { functions: program.functions
  , types: program.types
  , ctors: program.ctors
  , locals: []
  }

checkFunction
  ∷ Env → Resolved.FunctionDecl → Either Diagnostic IR.FunctionDecl
checkFunction env function = do
  body ← infer scoped function.body
  require scoped function.result body
  pure
    { id: function.id
    , parameters: map parameterType function.parameters
    , result: function.result
    , body
    , span: function.span
    }
  where
  scoped = env
    { locals = Array.mapWithIndex parameterLocal function.parameters }
  parameterType parameter = parameter.ty
  parameterLocal index parameter =
    { id: Resolved.LocalId index, ty: parameter.ty }

require ∷ Env → Ty → IR.Expr → Either Diagnostic Unit
require env expected actual =
  if expected == IR.typeOf actual then Right unit
  else mismatch
  where
  mismatch = Left
    ( problem TypeMismatch (IR.spanOf actual)
        ( "Expected " <> describe env.types expected <> ", found "
            <> describe env.types (IR.typeOf actual)
        )
    )

infer ∷ Env → Resolved.Expr → Either Diagnostic IR.Expr
infer env expression = case expression of
  Resolved.Integer span value → checkedInteger span value
  Resolved.Boolean span value → checkedBoolean span value
  Resolved.Local span id → checkLocal env span id
  Resolved.Call span id arguments → checkCall env span id arguments
  Resolved.Construct span id arguments → checkConstruct env span id arguments
  Resolved.Add span left right → checkAddition env span left right
  Resolved.If span condition yes no → checkConditional env span condition yes
    no

checkedInteger ∷ Span → Int → Either Diagnostic IR.Expr
checkedInteger span value = pure
  (IR.Expr { ty: TInt, span, node: IR.Integer value })

checkedBoolean ∷ Span → Boolean → Either Diagnostic IR.Expr
checkedBoolean span value = pure
  (IR.Expr { ty: TBool, span, node: IR.Boolean value })

checkAddition
  ∷ Env
  → Span
  → Resolved.Expr
  → Resolved.Expr
  → Either Diagnostic IR.Expr
checkAddition env span left right = do
  first ← infer env left
  second ← infer env right
  require env TInt first
  require env TInt second
  pure (IR.Expr { ty: TInt, span, node: IR.Add first second })

checkConditional
  ∷ Env
  → Span
  → Resolved.Expr
  → Resolved.Expr
  → Resolved.Expr
  → Either Diagnostic IR.Expr
checkConditional env span condition yes no = do
  predicate ← infer env condition
  require env TBool predicate
  first ← infer env yes
  second ← infer env no
  require env (IR.typeOf first) second
  pure
    ( IR.Expr
        { ty: IR.typeOf first
        , span
        , node: IR.If predicate first second
        }
    )

checkLocal
  ∷ Env → Span → Resolved.LocalId → Either Diagnostic IR.Expr
checkLocal env span id = maybe' missing found
  (Array.find named env.locals)
  where
  missing _ = Left (problem InternalError span "Invalid resolved local")
  found local = pure (IR.Expr { ty: local.ty, span, node: IR.Local id })
  named local = local.id == id

checkCall
  ∷ Env
  → Span
  → Resolved.FunctionId
  → Array Resolved.Expr
  → Either Diagnostic IR.Expr
checkCall env span id@(Resolved.FunctionId index) arguments = maybe'
  missing
  found
  (Array.index env.functions index)
  where
  missing _ = Left (problem InternalError span "Invalid resolved function")
  found function = do
    checked ← checkArguments env span (map parameterType function.parameters)
      arguments
    pure
      (IR.Expr { ty: function.result, span, node: IR.Call id checked })
  parameterType parameter = parameter.ty

checkConstruct
  ∷ Env
  → Span
  → Resolved.CtorId
  → Array Resolved.Expr
  → Either Diagnostic IR.Expr
checkConstruct env span id@(Resolved.CtorId index) arguments = maybe'
  missing
  found
  (Array.index env.ctors index)
  where
  missing _ = Left (problem InternalError span "Invalid resolved constructor")
  found ctor = do
    checked ← checkArguments env span ctor.fields arguments
    pure
      ( IR.Expr
          { ty: TData ctor.owner, span, node: IR.Construct id checked }
      )

-- Arity is checked before any argument, as Stage 0 calls always did.
checkArguments
  ∷ Env
  → Span
  → Array Ty
  → Array Resolved.Expr
  → Either Diagnostic (Array IR.Expr)
checkArguments env span expected arguments = do
  when (Array.length arguments /= Array.length expected)
    (Left (problem ArityMismatch span "Wrong number of arguments"))
  checked ← traverse checkExpression arguments
  _ ← traverse checkArgument (Array.zipWith argumentPair expected checked)
  pure checked
  where
  checkExpression argument = infer env argument
  argumentPair ty actual = { ty, actual }
  checkArgument pair = require env pair.ty pair.actual
