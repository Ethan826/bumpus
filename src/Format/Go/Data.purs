module Format.Go.Data
  ( declarations
  , goType
  , ctorName
  , functionName
  , fieldName
  , localName
  , integer
  , boolean
  , malformed
  ) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal (Ty(..))
import Domain.Resolved (CtorId(..), FunctionId(..), LocalId(..), TypeId(..))
import Format.Go.Layout (Declared, Layout, Member)

-- Each type becomes one tagged struct and its constructor functions.
declarations ∷ Layout → String
declarations program = joinWith "" (map typeBlock program.types)
  where
  typeBlock declared = structDeclaration declared
    <> joinWith "" (map constructor declared.members)

goType ∷ Ty → String
goType = case _ of
  TInt → "int32"
  TBool → "bool"
  TData (TypeId index) → "bumpusTy" <> show index

ctorName ∷ CtorId → String
ctorName (CtorId index) = "bumpusCtor" <> show index

functionName ∷ FunctionId → String
functionName (FunctionId index) = "bumpusFn" <> show index

localName ∷ LocalId → String
localName (LocalId index) = "bumpusLocal" <> show index

integer ∷ Int → String
integer value = "int32(" <> show value <> ")"

boolean ∷ Boolean → String
boolean value = if value then "true" else "false"

-- Raised by every helper that meets a value its declarations cannot
-- produce: an unknown tag or a nil field (only foreign code, I001).
malformed ∷ String
malformed = "panic(\"bumpus: malformed value\")"

typeName ∷ TypeId → String
typeName (TypeId index) = "bumpusTy" <> show index

fieldName ∷ CtorId → Int → String
fieldName (CtorId ctor) index = "c" <> show ctor <> "f" <> show index

-- ADT fields are pointers so a type may contain itself.
fieldType ∷ Ty → String
fieldType = case _ of
  TData (TypeId index) → "*bumpusTy" <> show index
  other → goType other

structDeclaration ∷ Declared → String
structDeclaration declared =
  "type " <> typeName declared.id <> " struct {\ntag uint32\n"
    <> joinWith "" (Array.concatMap fieldLines declared.members)
    <> "}\n\n"
  where
  fieldLines member = Array.mapWithIndex (fieldLine member.id)
    member.ctor.fields
  fieldLine id index ty = fieldName id index <> " " <> fieldType ty <> "\n"

-- Tags are 1-based within the owner so the zero value never names a
-- constructor (Format.Go.Layout). Constructor ids are unique across types.
constructor ∷ Member → String
constructor member =
  "func " <> ctorName member.id <> "(" <> joinWith ", " parameters
    <> ") "
    <> typeName member.ctor.owner
    <> " { return "
    <> typeName member.ctor.owner
    <> "{"
    <> joinWith ", " ([ "tag: " <> show member.tag ] <> stores)
    <> "} }\n\n"
  where
  parameters = Array.mapWithIndex parameter member.ctor.fields
  parameter index ty = "f" <> show index <> " " <> goType ty
  stores = Array.mapWithIndex store member.ctor.fields
  store index ty =
    fieldName member.id index <> ": " <> storedValue ty ("f" <> show index)

storedValue ∷ Ty → String → String
storedValue ty name = case ty of
  TData _ → "&" <> name
  _ → name
