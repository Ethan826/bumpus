module Domain.IR.Internal where

import Prelude
import Domain.Syntax (Operator, Span)
import Domain.Resolved (CtorId, FunctionId, LocalId, TypeId)

-- The monomorphic IR Go generation reads. Its `Ty` has no variable, so no
-- type variable can reach Go by construction. Constructors are internal to
-- specialization and lowering, enforced by the structure gate.
data Ty = TInt | TBool | TData TypeId

derive instance eqTy ∷ Eq Ty

type TypeInfo = { name ∷ String, ctors ∷ Array CtorId, span ∷ Span }

type CtorInfo =
  { name ∷ String, owner ∷ TypeId, fields ∷ Array Ty, span ∷ Span }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

newtype Program = Program
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

-- The source name is carried for diagnostics; Go names functions by id.
type FunctionDecl =
  { id ∷ FunctionId
  , name ∷ String
  , parameters ∷ Array Ty
  , result ∷ Ty
  , body ∷ Expr
  , span ∷ Span
  }

data Expr = Expr { ty ∷ Ty, span ∷ Span, node ∷ Node }

data Node
  = Integer Int
  | Boolean Boolean
  | Local LocalId
  | Call FunctionId (Array Expr)
  | Construct CtorId (Array Expr)
  | Add Expr Expr
  | Compare Operator Expr Expr
  | If Expr Expr Expr
  | Match Expr (Array Arm)

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }

-- A pattern carries the type it was checked against; lowering reads it.
data Pattern = Pattern { ty ∷ Ty, span ∷ Span, shape ∷ Shape }

data Shape
  = Wildcard
  | Bind LocalId
  | IntLit Int
  | BoolLit Boolean
  | Ctor CtorId (Array Pattern)

typeOf ∷ Expr → Ty
typeOf (Expr expression) = expression.ty

spanOf ∷ Expr → Span
spanOf (Expr expression) = expression.span
