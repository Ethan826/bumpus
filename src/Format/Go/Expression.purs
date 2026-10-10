module Format.Go.Expression (expression) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty)
import Format.Go.Block (lowerBlock)
import Format.Go.Compare (comparison)
import Format.Go.Data (boolean, goType, integer, localName)
import Format.Go.Capture (union)
import Format.Go.Effect (lowerHandlerValue)
import Format.Go.Handle (lowerAbort, lowerHandle, lowerInstall)
import Format.Go.Lambda (lowerLambda)
import Format.Go.Lowered
  ( Lowered
  , Scope
  , Several
  , both
  , ctorWrapper
  , functionWrapper
  , leaf
  , operationWrapper
  , several
  , variable
  )
import Format.Go.Match (lowerMatch)
import Format.Go.Pipe (lowerPipe)
import Format.Go.Report (lowerCrash)
import Format.Go.Show (printed)
import Format.Go.Value (applyValue, named, reference)

-- `next` is the number the first lifted function met in pre-order will
-- take; each match, lambda, temporary pipe, application helper and block
-- becomes its own top-level function (Format.Go.Match, .Lambda, .Pipe,
-- .Apply, .Block). Unit is Go's `struct{}`, its value `struct{}{}`.
-- One arm per node, each delegating; a flat exhaustive dispatch.
expression ∷ Scope → Int → IR.Expr → Lowered
expression scope next whole@(IR.Expr term) = case term.node of
  IR.Integer value → leaf next (integer value)
  IR.Boolean value → leaf next (boolean value)
  IR.Local id → variable next (localName id) id term.ty
  IR.Call id arguments →
    named scope lower next (functionWrapper scope.shape id) whole arguments
  IR.Construct id arguments →
    named scope lower next (ctorWrapper scope.shape id) whole arguments
  IR.Add left right → pair addition left right
  IR.Compare operator left right →
    pair (comparison operator (IR.typeOf left)) left right
  IR.If condition yes no →
    joined (conditional term.ty) (each [ condition, yes, no ])
  IR.Match scrutinee arms → lowerMatch scope lower next term.ty scrutinee arms
  IR.FunctionRef id → reference next (functionWrapper scope.shape id)
  IR.CtorRef id → reference next (ctorWrapper scope.shape id)
  IR.Apply callee arguments → applyValue scope lower next callee arguments
  IR.Lambda parameters body →
    lowerLambda scope lower next whole parameters body
  IR.Pipe left right → lowerPipe scope lower next whole left right
  IR.UnitValue → leaf next "struct{}{}"
  IR.Print value → printedValue (IR.typeOf value) (lower next value)
  IR.Crash value → lowerCrash lower next term.ty value
  IR.Block items value → lowerBlock scope lower next term.ty items value
  IR.OperationRef key position →
    reference next (operationWrapper scope.shape key position)
  IR.Perform key position arguments →
    named scope lower next (operationWrapper scope.shape key position) whole
      arguments
  IR.HandlerValue key clauses → lowerHandlerValue scope lower next key clauses
  IR.Install handler body →
    lowerInstall scope lower next term.ty handler body
  IR.Handle body clauses → lowerHandle scope lower next term.ty body clauses
  IR.Abort family value → lowerAbort scope lower next term.ty family value
  where
  lower = expression scope
  each = several lower next
  pair = both lower next

joined ∷ (Array String → String) → Several → Lowered
joined render parts =
  { code: render parts.codes
  , next: parts.next
  , lifted: parts.lifted
  , free: union parts.frees
  , wrappers: parts.wrappers
  }

addition ∷ String → String → String
addition left right = "waxwingAdd(" <> left <> ", " <> right <> ")"

-- `if` keeps its immediately invoked closure; nested `if` branches build
-- at the nesting limit (test/depth.test.mjs), unlike nested match closures.
conditional ∷ Ty → Array String → String
conditional ty codes = joinWith "" (Array.zipWith append pieces codes)
  <> " }()"
  where
  pieces = [ "func() " <> goType ty <> " { if ", " { return ", " }; return " ]

printedValue ∷ Ty → Lowered → Lowered
printedValue ty value = value
  { code = "func() struct{} { fmt.Println("
      <> printed ty value.code
      <> "); return struct{}{} }()"
  }
