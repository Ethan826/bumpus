module Domain.Problem where

-- What went wrong, as data. Features never write diagnostic text; Format
-- renders it, so a change of surface syntax changes only Format.

-- `HoleName` is a type checking left open, rendered `_`. `FunctionName`
-- is one arrow, parameter then result, curried like `Ty`'s.
data TypeName
  = IntName
  | BoolName
  | DataName String
  | AppliedName String (Array TypeName)
  | VariableName String
  | HoleName
  | FunctionName TypeName TypeName

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

data EntryKind
  = MissingEntry
  | EntryParameters
  | EntryPolymorphic
  | EntryFunction

-- What a diagnostic suggests beside its problem: a partial application
-- of the named function or constructor, short of this many arguments.
data Hint = MissingArguments String Int

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
  | FunctionNeedsCall String
  | Arity
  | FieldArity
  | TypeArguments String
  | TypeMismatch TypeName TypeName
  | NotAFunction TypeName
  | InfiniteType TypeName TypeName
  | NotComparable TypeName
  | AmbiguousType TypeName
  | PolymorphicRecursion String
  | NestedDatatype String
  | SpecializationLimit Int
  | RedundantArm
  | NonExhaustive Witness
  | Internal String
  -- Rendered as its problem, with the hint after; code and span unchanged.
  | Hinted Problem Hint
