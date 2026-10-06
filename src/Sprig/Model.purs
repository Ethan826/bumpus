module Sprig.Model where

import Prelude

type Position = { offset ∷ Int, line ∷ Int, column ∷ Int }
type Span = { start ∷ Position, end ∷ Position }
type Diagnostic = { code ∷ ErrorCode, message ∷ String, span ∷ Span }
type Token = { text ∷ String, span ∷ Span }

data Ty = TInt | TBool

derive instance eqType ∷ Eq Ty

instance showType ∷ Show Ty where
  show TInt = "Int"
  show TBool = "Bool"

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Variable Span String
  | Call Span String (Array Expr)
  | Add Span Expr Expr
  | If Span Expr Expr Expr

type Parameter = { name ∷ String, ty ∷ Ty, span ∷ Span }
type FunctionDecl =
  { name ∷ String
  , parameters ∷ Array Parameter
  , result ∷ Ty
  , body ∷ Expr
  , span ∷ Span
  }

data ErrorCode
  = LexError
  | SyntaxError
  | IntegerRange
  | EntryError
  | DuplicateName
  | UnboundName
  | NotCallable
  | TypeMismatch
  | InternalError
  | ArityMismatch

derive instance eqErrorCode ∷ Eq ErrorCode

origin ∷ Position
origin = { offset: 0, line: 1, column: 1 }

exprSpan ∷ Expr → Span
exprSpan = case _ of
  Integer span _ → span
  Boolean span _ → span
  Variable span _ → span
  Call span _ _ → span
  Add span _ _ → span
  If span _ _ _ → span

problem ∷ ErrorCode → Span → String → Diagnostic
problem code span message = { code, span, message }

codeName ∷ ErrorCode → String
codeName = case _ of
  LexError → "E_LEX"
  SyntaxError → "E_SYNTAX"
  IntegerRange → "E_INTEGER"
  EntryError → "E_ENTRY"
  DuplicateName → "E_DUPLICATE"
  UnboundName → "E_UNBOUND"
  NotCallable → "E_NOT_CALLABLE"
  TypeMismatch → "E_TYPE"
  InternalError → "E_INTERNAL"
  ArityMismatch → "E_ARITY"
