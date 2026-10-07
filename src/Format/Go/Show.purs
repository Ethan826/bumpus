module Format.Go.Show (showName, showHelpers, printed) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeId(..), TypeInfo)
import Format.Go.Data (fieldName, goType, malformed, tagOf)

showName ∷ TypeId → String
showName (TypeId index) = "sprigShow" <> show index

-- One printer per declared type, in TypeId order, whether or not used.
showHelpers ∷ Array TypeInfo → Array CtorInfo → String
showHelpers types ctors = joinWith "" (Array.mapWithIndex helper types)
  where
  helper index _ = showHelper types ctors (TypeId index)

-- What `main` passes to fmt.Println: Int and Bool print natively, so their
-- output is unchanged; a declared value is rendered by its printer.
printed ∷ Ty → String → String
printed ty call = case ty of
  TData owner → "string(" <> showName owner <> "(nil, " <> call <> "))"
  _ → call

-- Cases come from the constructor table itself, so every constructor of
-- the type is printed with all its fields and no lookup can come up empty.
-- Any tag without a case is malformed (I001 foreign values).
showHelper ∷ Array TypeInfo → Array CtorInfo → TypeId → String
showHelper types ctors owner =
  "func " <> showName owner <> "(out []byte, v " <> goType (TData owner)
    <> ") []byte {\nswitch v.tag {\n"
    <> joinWith "" (Array.mapWithIndex (showCase types owner) ctors)
    <> "}\n"
    <> malformed
    <> "\n}\n\n"

showCase ∷ Array TypeInfo → TypeId → Int → CtorInfo → String
showCase types owner index ctor
  | ctor.owner /= owner = ""
  | otherwise = "case " <> show (tagOf types (CtorId index)) <> ":\n"
      <> ctorBody (CtorId index) ctor

-- Printed values are Sprig expressions: `Name` or `Name(f1, f2)`.
ctorBody ∷ CtorId → CtorInfo → String
ctorBody id ctor
  | Array.null ctor.fields = "return " <> appendText ctor.name
  | otherwise =
      "out = " <> appendText (ctor.name <> "(")
        <> joinWith ("out = " <> appendText ", ") fields
        <> "return append(out, ')')\n"
      where
      fields = Array.mapWithIndex (showField id) ctor.fields

showField ∷ CtorId → Int → Ty → String
showField id position = case _ of
  TData owner → "if " <> field <> " == nil { " <> malformed <> " }\n"
    <> "out = "
    <> showName owner
    <> "(out, *"
    <> field
    <> ")\n"
  _ → "out = fmt.Append(out, " <> field <> ")\n"
  where
  field = "v." <> fieldName id position

appendText ∷ String → String
appendText text = "append(out, \"" <> text <> "\"...)\n"
