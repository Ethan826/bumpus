module Domain.Problem where

-- What went wrong, as data. Features never write diagnostic text; Format
-- renders it, so a change of surface syntax changes only Format.

-- `HoleName` is a type checking left open, rendered `_`.
data TypeName
  = IntName
  | BoolName
  | DataName String
  | AppliedName String (Array TypeName)
  | VariableName String
  | HoleName

-- A missing value, with constructor names already resolved.
data Witness = WAny | WCtor String (Array Witness) | WInt Int | WBool Boolean

data UnboundKind
  = UnboundLocal
  | UnboundFunction
  | UnboundConstructor
  | UnboundType
  | UnboundTypeVariable

data DuplicateKind
  = DuplicateType
  | DuplicateConstructor
  | DuplicateFunction
  | DuplicateParameter
  | DuplicateBinder
  | DuplicateTypeParameter

data EntryKind = MissingEntry | EntryParameters | EntryPolymorphic

-- The lexer and parser are Format, so their payloads may be text.
data Problem
  = Lexical
  | Syntax String
  | IntegerOutOfRange
  | NestingTooDeep Int
  | TypeTooDeep Int
  | EntryProblem EntryKind
  | Duplicate DuplicateKind String
  | Unbound UnboundKind String
  | NotCallable String
  | CtorNotCallable String
  | CtorNeedsArguments String
  | Arity
  | FieldArity
  | TypeArguments String
  | TypeMismatch TypeName TypeName
  | InfiniteType TypeName TypeName
  | NotComparable TypeName
  | AmbiguousType TypeName
  | PolymorphicRecursion String
  | NestedDatatype String
  | RedundantArm
  | NonExhaustive Witness
  | Internal String
