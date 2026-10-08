module Format.Go.Show (showName, showHelpers, printed) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal (CtorInfo, Ty(..))
import Domain.Resolved (CtorId, TypeId(..))
import Format.Go.Data (fieldName, goType, malformed)
import Format.Go.Layout (Declared, Layout, Member)

showName ∷ TypeId → String
showName (TypeId index) = "bumpusShow" <> show index

-- One printer per declared type, in TypeId order, whether or not used.
showHelpers ∷ Layout → String
showHelpers program = joinWith "" (map showHelper program.types)

-- What `main` passes to fmt.Println: Int and Bool print natively, so their
-- output is unchanged; a declared value is rendered by its printer.
printed ∷ Ty → String → String
printed ty call = case ty of
  TData owner → "string(" <> showName owner <> "(nil, " <> call <> "))"
  _ → call

-- Cases come from the type's members, which Format.Go.Layout joins with
-- the constructor table itself, so every constructor of the type is printed
-- with all its fields and no lookup can come up empty. Any tag without a
-- case is malformed (I001 foreign values).
showHelper ∷ Declared → String
showHelper declared =
  "func " <> showName declared.id <> "(out []byte, v "
    <> goType (TData declared.id)
    <> ") []byte {\nswitch v.tag {\n"
    <> joinWith "" (map showCase declared.members)
    <> "}\n"
    <> malformed
    <> "\n}\n\n"

showCase ∷ Member → String
showCase member = "case " <> show member.tag <> ":\n"
  <> ctorBody member.id member.ctor

-- Printed values are Bumpus expressions: `Name` or `Name(f1, f2)`.
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
