module Domain.Problem where

-- What went wrong, as data. Features never write diagnostic text; Format
-- renders it, so a change of surface syntax changes only Format.

data TypeName = IntName | BoolName | DataName String

-- A missing value, with constructor names already resolved.
data Witness = WAny | WCtor String (Array Witness) | WInt Int | WBool Boolean

data UnboundKind
  = UnboundLocal
  | UnboundFunction
  | UnboundConstructor
  | UnboundType

data DuplicateKind
  = DuplicateType
  | DuplicateConstructor
  | DuplicateFunction
  | DuplicateParameter
  | DuplicateBinder

data EntryKind = MissingEntry | EntryParameters | EntryResult

-- The lexer and parser are Format, so their payloads may be text.
data Problem
  = Lexical
  | Syntax String
  | IntegerOutOfRange
  | EntryProblem EntryKind
  | Duplicate DuplicateKind String
  | Unbound UnboundKind String
  | NotCallable String
  | CtorNotCallable String
  | CtorNeedsArguments String
  | Arity
  | FieldArity
  | TypeMismatch TypeName TypeName
  | RedundantArm
  | NonExhaustive Witness
  | Internal String
