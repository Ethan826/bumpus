module Domain.Resolved where

import Prelude
import Domain.Syntax (Operator, Span)

newtype FunctionId = FunctionId Int
newtype LocalId = LocalId Int
newtype TypeId = TypeId Int
newtype CtorId = CtorId Int

derive instance eqFunctionId ∷ Eq FunctionId
derive instance eqLocalId ∷ Eq LocalId
derive instance eqTypeId ∷ Eq TypeId
derive instance eqCtorId ∷ Eq CtorId

data Ty = TInt | TBool | TData TypeId

derive instance eqTy ∷ Eq Ty

type TypeInfo = { name ∷ String, ctors ∷ Array CtorId, span ∷ Span }

type CtorInfo =
  { name ∷ String, owner ∷ TypeId, fields ∷ Array Ty, span ∷ Span }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

-- The resolver's scope entry: a source name and the id it resolves to.
type Local = { name ∷ String, id ∷ LocalId }

data GlobalRef = FunctionRef FunctionId | CtorRef CtorId

-- Functions and constructors share one global namespace.
type Global = { name ∷ String, ref ∷ GlobalRef }

-- A result plus the next free LocalId, threaded in source pre-order.
type Numbered a = { value ∷ a, next ∷ Int }

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
  | Call Span FunctionId (Array Expr)
  | Construct Span CtorId (Array Expr)
  | Add Span Expr Expr
  | Compare Span Operator Expr Expr
  | If Span Expr Expr Expr
  | Match Span Expr (Array Arm)

type Parameter = { name ∷ String, ty ∷ Ty, span ∷ Span }

type FunctionDecl =
  { id ∷ FunctionId
  , parameters ∷ Array Parameter
  , result ∷ Ty
  , body ∷ Expr
  , span ∷ Span
  }

type Program =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

exprSpan ∷ Expr → Span
exprSpan expression = case expression of
  Integer span _ → span
  Boolean span _ → span
  Local span _ → span
  Call span _ _ → span
  Construct span _ _ → span
  Add span _ _ → span
  Compare span _ _ _ → span
  If span _ _ _ → span
  Match span _ _ → span
