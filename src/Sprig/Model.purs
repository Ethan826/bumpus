module Sprig.Model where

import Prelude
import Data.Maybe (maybe)
import Data.String.CodeUnits as String

type Position = { offset ∷ Int, line ∷ Int, column ∷ Int }
type Span = { start ∷ Position, end ∷ Position }
type Diagnostic = { code ∷ ErrorCode, message ∷ String, span ∷ Span }
type Token = { text ∷ String, span ∷ Span }

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Variable Span String
  | Call Span String (Array Expr)
  | Add Span Expr Expr
  | If Span Expr Expr Expr
  | Match Span Expr (Array Arm)

data Pattern
  = PWildcard Span
  | PBind Span String
  | PInt Span Int
  | PBool Span Boolean
  | PCtor Span String (Array Pattern)

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }

data TypeRef = IntRef Span | BoolRef Span | NamedRef Span String

type CtorDecl = { name ∷ String, fields ∷ Array TypeRef, span ∷ Span }
type TypeDecl = { name ∷ String, ctors ∷ Array CtorDecl, span ∷ Span }

type Parameter = { name ∷ String, ty ∷ TypeRef, span ∷ Span }
type FunctionDecl =
  { name ∷ String
  , parameters ∷ Array Parameter
  , result ∷ TypeRef
  , body ∷ Expr
  , span ∷ Span
  }

type Program = { types ∷ Array TypeDecl, functions ∷ Array FunctionDecl }

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
  | Redundant
  | NonExhaustive

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
  Match span _ _ → span

patternSpan ∷ Pattern → Span
patternSpan = case _ of
  PWildcard span → span
  PBind span _ → span
  PInt span _ → span
  PBool span _ → span
  PCtor span _ _ → span

isUpper ∷ String → Boolean
isUpper text = maybe false upper (String.charAt 0 text)
  where
  upper character = character >= 'A' && character <= 'Z'

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
  Redundant → "E_REDUNDANT"
  NonExhaustive → "E_NON_EXHAUSTIVE"
