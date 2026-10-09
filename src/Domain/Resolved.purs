module Domain.Resolved
  ( module Domain.Resolved
  , module Domain.Type
  ) where

import Prelude
import Data.Maybe (Maybe)
import Domain.Syntax (Operator, Sort, Span, TypeRef)
import Domain.Ids (EffectId)
import Domain.Type (Ty(..), TyRow, TypeId(..), VarId(..))
import Domain.Row (Label)

newtype FunctionId = FunctionId Int
newtype LocalId = LocalId Int
newtype CtorId = CtorId Int

derive instance eqFunctionId ∷ Eq FunctionId
derive instance eqLocalId ∷ Eq LocalId
derive instance ordLocalId ∷ Ord LocalId
derive instance eqCtorId ∷ Eq CtorId

-- `VarId i` in a constructor field is the owner's i-th parameter.
type TypeInfo =
  { name ∷ String
  , parameters ∷ Array String
  , rowParameters ∷ Array String
  , variables ∷ Array String
  , sorts ∷ Array Sort
  , sourceSorts ∷ Array Sort
  , ctors ∷ Array CtorId
  , span ∷ Span
  }

-- Field types are over the owner's parameters. `fieldSyntax` keeps each
-- field's source reference, whose nested spans diagnostics point into.
type CtorInfo =
  { name ∷ String
  , owner ∷ TypeId
  , fields ∷ Array (Ty VarId)
  , fieldSyntax ∷ Array TypeRef
  , span ∷ Span
  }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

-- The resolver's scope entry: a source name and the id it resolves to.
type Local = { name ∷ String, id ∷ LocalId }

-- A function carries its declared parameter count, which decides what its
-- bare name means (FN001 design §2).
data GlobalRef
  = GlobalFunction FunctionId Int
  | GlobalCtor CtorId
  | Operation EffectId Int Int
  | BuiltinPrint

-- Functions and constructors share one global namespace.
type Global = { name ∷ String, ref ∷ GlobalRef }

data Pattern
  = Wildcard Span
  | Bind Span LocalId
  | IntLit Span Int
  | BoolLit Span Boolean
  | Ctor Span CtorId (Array Pattern)

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Local Span LocalId
  | FunctionRef Span FunctionId
  | CtorRef Span CtorId
  | Call Span FunctionId (Array Expr)
  | Construct Span CtorId (Array Expr)
  | Add Span Expr Expr
  | Compare Span Operator Expr Expr
  | If Span Expr Expr Expr
  | Match Span Expr (Array Arm)
  | Lambda Span (Array Param) Expr
  | Apply Span Expr (Array Expr)
  | Pipe Span Expr Expr
  | UnitValue Span
  | Block Span (Array Item) Expr
  | OperationRef Span EffectId Int
  | Perform Span EffectId Int (Array Expr)
  | PrintRef Span
  | Print Span (Array Expr)
  | Handler Span (Label (Ty VarId)) (Array HandlerClause)
  | With Span Expr Expr
  | Handle Span Expr (Array FailClause)
  | Fail Span Expr

type HandlerClause =
  { operation ∷ Int
  , result ∷ Ty VarId
  , parameters ∷ Array HandlerParameter
  , body ∷ Expr
  , span ∷ Span
  }

type HandlerParameter = { local ∷ Maybe LocalId, ty ∷ Ty VarId }
type FailClause =
  { label ∷ Label (Ty VarId)
  , local ∷ Maybe LocalId
  , body ∷ Expr
  , span ∷ Span
  }

-- A block item: `let` binds a local, or `_` (Nothing); a discarded item's
-- value is evaluated and dropped (FX001 design §1).
data Item = Let Span (Maybe LocalId) Expr | Discard Expr

-- A lambda parameter: a local, or `_` (Nothing), which binds nothing. Its
-- annotation names only the enclosing signature's variables.
type Param = { local ∷ Maybe LocalId, ty ∷ Maybe (Ty VarId), span ∷ Span }

type Parameter = { name ∷ String, ty ∷ Ty VarId, span ∷ Span }

-- `VarId i` in a signature is `variables !! i`: the i-th distinct type
-- variable in first-occurrence order, parameters then result.
type FunctionDecl =
  { id ∷ FunctionId
  , name ∷ String
  , variables ∷ Array String
  , sorts ∷ Array Sort
  , row ∷ TyRow VarId
  , parameters ∷ Array Parameter
  , result ∷ Ty VarId
  , body ∷ Expr
  , span ∷ Span
  }

-- `syntax` keeps the parameter types', then the result's, source
-- references, as `fieldSyntax` does for constructors (FX001 Task 6).
type OperationInfo =
  { name ∷ String
  , parameters ∷ Array Parameter
  , result ∷ Ty VarId
  , syntax ∷ Array TypeRef
  , span ∷ Span
  }

type EffectInfo =
  { name ∷ String
  , parameters ∷ Array String
  , operations ∷ Array OperationInfo
  , span ∷ Span
  }

type Program =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , effects ∷ Array EffectInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

exprSpan ∷ Expr → Span
exprSpan expression = case expression of
  Integer span _ → span
  Boolean span _ → span
  Local span _ → span
  FunctionRef span _ → span
  CtorRef span _ → span
  Call span _ _ → span
  Construct span _ _ → span
  Add span _ _ → span
  Compare span _ _ _ → span
  If span _ _ _ → span
  Match span _ _ → span
  Lambda span _ _ → span
  Apply span _ _ → span
  Pipe span _ _ → span
  UnitValue span → span
  Block span _ _ → span
  OperationRef span _ _ → span
  Perform span _ _ _ → span
  PrintRef span → span
  Print span _ → span
  Handler span _ _ → span
  With span _ _ → span
  Handle span _ _ → span
  Fail span _ → span
