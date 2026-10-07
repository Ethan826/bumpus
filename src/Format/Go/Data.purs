module Format.Go.Data
  ( declarations
  , goType
  , ctorName
  , fieldName
  , tagOf
  , localName
  , integer
  , boolean
  , malformed
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe, maybe)
import Data.String.Common (joinWith)
import Domain.Resolved
  ( CtorId(..)
  , CtorInfo
  , LocalId(..)
  , Ty(..)
  , TypeId(..)
  , TypeInfo
  )

-- Each type becomes one tagged struct and its constructor functions.
declarations ∷ Array TypeInfo → Array CtorInfo → String
declarations types ctors = joinWith "" (Array.mapWithIndex typeBlock types)
  where
  typeBlock index info = structDeclaration (TypeId index) ctors info
    <> joinWith "" (map (constructor types ctors) info.ctors)

goType ∷ Ty → String
goType = case _ of
  TInt → "int32"
  TBool → "bool"
  TData (TypeId index) → "sprigTy" <> show index

ctorName ∷ CtorId → String
ctorName (CtorId index) = "sprigCtor" <> show index

localName ∷ LocalId → String
localName (LocalId index) = "sprigLocal" <> show index

integer ∷ Int → String
integer value = "int32(" <> show value <> ")"

boolean ∷ Boolean → String
boolean value = if value then "true" else "false"

-- Raised by every helper that meets a value its declarations cannot
-- produce: an unknown tag or a nil field (only foreign code, I001).
malformed ∷ String
malformed = "panic(\"sprig: malformed value\")"

-- Tags are 1-based within the owner so the zero value never names a
-- constructor. Constructor ids are unique across types.
tagOf ∷ Array TypeInfo → CtorId → Int
tagOf types id = maybe 0 (add 1) (Array.findMap position types)
  where
  position info = Array.elemIndex id info.ctors

typeName ∷ TypeId → String
typeName (TypeId index) = "sprigTy" <> show index

fieldName ∷ CtorId → Int → String
fieldName (CtorId ctor) index = "c" <> show ctor <> "f" <> show index

-- ADT fields are pointers so a type may contain itself.
fieldType ∷ Ty → String
fieldType = case _ of
  TData (TypeId index) → "*sprigTy" <> show index
  other → goType other

structDeclaration ∷ TypeId → Array CtorInfo → TypeInfo → String
structDeclaration owner ctors info =
  "type " <> typeName owner <> " struct {\ntag uint32\n"
    <> joinWith "" (Array.concatMap fieldLines info.ctors)
    <> "}\n\n"
  where
  fieldLines id = maybe [] (lines id) (ctorAt ctors id)
  lines id ctor = Array.mapWithIndex (fieldLine id) ctor.fields
  fieldLine id index ty = fieldName id index <> " " <> fieldType ty <> "\n"

constructor ∷ Array TypeInfo → Array CtorInfo → CtorId → String
constructor types ctors id = maybe "" declared (ctorAt ctors id)
  where
  declared ctor =
    "func " <> ctorName id <> "(" <> joinWith ", " (parameters ctor)
      <> ") "
      <> typeName ctor.owner
      <> " { return "
      <> typeName ctor.owner
      <> "{"
      <> joinWith ", " ([ "tag: " <> show (tagOf types id) ] <> stores ctor)
      <> "} }\n\n"
  parameters ctor = Array.mapWithIndex parameter ctor.fields
  parameter index ty = "f" <> show index <> " " <> goType ty
  stores ctor = Array.mapWithIndex store ctor.fields
  store index ty =
    fieldName id index <> ": " <> storedValue ty ("f" <> show index)

storedValue ∷ Ty → String → String
storedValue ty name = case ty of
  TData _ → "&" <> name
  _ → name

ctorAt ∷ Array CtorInfo → CtorId → Maybe CtorInfo
ctorAt ctors (CtorId index) = Array.index ctors index
