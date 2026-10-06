module Sprig.IR.Internal where

import Sprig.Model (Span)
import Sprig.Resolved (CtorId, CtorInfo, FunctionId, LocalId, Ty, TypeInfo)

-- Constructors are internal to elaboration and lowering, enforced by the gate.
newtype Program = Program
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

type FunctionDecl =
  { id ∷ FunctionId
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
  | If Expr Expr Expr

typeOf ∷ Expr → Ty
typeOf (Expr expression) = expression.ty

spanOf ∷ Expr → Span
spanOf (Expr expression) = expression.span
