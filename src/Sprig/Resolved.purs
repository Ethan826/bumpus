module Sprig.Resolved where

import Sprig.Model (Span, Ty)

newtype FunctionId = FunctionId Int
newtype LocalId = LocalId Int

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Local Span LocalId
  | Call Span FunctionId (Array Expr)
  | Add Span Expr Expr
  | If Span Expr Expr Expr

type Parameter = { name ∷ String, ty ∷ Ty, span ∷ Span }

type FunctionDecl =
  { id ∷ FunctionId
  , parameters ∷ Array Parameter
  , result ∷ Ty
  , body ∷ Expr
  , span ∷ Span
  }

type Program = { functions ∷ Array FunctionDecl, entry ∷ FunctionId }

exprSpan ∷ Expr → Span
exprSpan expression = case expression of
  Integer span _ → span
  Boolean span _ → span
  Local span _ → span
  Call span _ _ → span
  Add span _ _ → span
  If span _ _ _ → span
