-- The evidence context of effects (FX001 design §4). The mode is chosen
-- over the emitted IR, not over what `main` reaches: specialization emits
-- every monomorphic function, so one unused function that performs an
-- operation still needs the context. In that mode every function, stage,
-- lambda and function value takes `ctx *waxwingCtx` first; otherwise
-- nothing changes and no runtime text is emitted.
module Format.Go.Context
  ( usesContext
  , children
  , runtime
  , contextParameter
  , declared
  , passed
  , parameterList
  , typeList
  , effectKey
  , failKey
  ) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.Ids (EffectId(..), TypeId(..))
import Domain.IR.Internal as IR
import Domain.Row (EffectRef(..), TypeHead(..))

-- Effect layouts exist for every handler type, so any of them, or any
-- effect node in a body, selects the mode.
usesContext ∷ IR.Program → Boolean
usesContext (IR.Program program) = not Array.null program.effects
  || Array.any inFunction program.functions
  where
  inFunction function = hasEffect function.body

hasEffect ∷ IR.Expr → Boolean
hasEffect (IR.Expr expression) = case expression.node of
  IR.OperationRef _ _ → true
  IR.Perform _ _ _ → true
  IR.HandlerValue _ _ → true
  IR.Install _ _ → true
  IR.Handle _ _ → true
  IR.Abort _ _ → true
  node → Array.any hasEffect (children node)

children ∷ IR.Node → Array IR.Expr
children = case _ of
  IR.Call _ arguments → arguments
  IR.Construct _ arguments → arguments
  IR.Add left right → [ left, right ]
  IR.Compare _ left right → [ left, right ]
  IR.If condition yes no → [ condition, yes, no ]
  IR.Match scrutinee arms → Array.cons scrutinee (map armBody arms)
  IR.Apply applied arguments → Array.cons applied arguments
  IR.Lambda _ body → [ body ]
  IR.Pipe left right → [ left, right ]
  IR.Print value → [ value ]
  IR.Crash value → [ value ]
  IR.Block items value → IR.blockParts items value
  _ → []
  where
  armBody arm = arm.body

-- The Go parameter, first in every signature of the mode.
contextParameter ∷ String
contextParameter = "ctx *waxwingCtx"

-- A signature's parameters, and a call's arguments, in the mode.
declared ∷ Boolean → Array String → Array String
declared context parameters
  | context = Array.cons contextParameter parameters
  | otherwise = parameters

passed ∷ Boolean → Array String → Array String
passed context arguments
  | context = Array.cons "ctx" arguments
  | otherwise = arguments

parameterList ∷ Boolean → Array String → String
parameterList context = joinWith ", " <<< declared context

-- The same in a function type, where Go wants all parameters named or
-- none.
typeList ∷ Boolean → Array String → String
typeList context types = joinWith ", "
  (if context then Array.cons "*waxwingCtx" types else types)

-- Runtime keys: user effects count from 1, failure families count down
-- from -1 by their payload's declared head (Fail layouts are keyed by the
-- full payload, which is not a runtime key), and the host effects, which
-- no frame ever holds, share 0.
effectKey ∷ EffectRef → Int
effectKey = case _ of
  UserEffect (EffectId index) → index + 1
  _ → 0

failKey ∷ TypeHead → Int
failKey = case _ of
  HeadInt → -1
  HeadBool → -2
  HeadUnit → -3
  HeadData (TypeId index) → -4 - index

-- Markers are non-zero-sized (Go lets distinct zero-sized variables share
-- an address) and compared by pointer only. `recover` runs directly in the
-- deferred function of waxwingHandle, as Go requires; it consumes only
-- aborts aimed at its own markers. The failure clause runs after it
-- returns, in the context of the `handle`.
runtime ∷ String
runtime =
  joinWith "\n"
    [ "type waxwingMarker struct{ id uint64 }"
    , "type waxwingAbort struct {"
    , "\ttarget  *waxwingMarker"
    , "\tpayload any"
    , "\treport  func(any) string"
    , "}"
    , "type waxwingCtx struct {"
    , "\tkey     int"
    , "\thandler any"
    , "\touter   *waxwingCtx"
    , "\tmarker  *waxwingMarker"
    , "}"
    , ""
    , "func waxwingInstall(outer *waxwingCtx, key int,"
    , "\thandler any) *waxwingCtx {"
    , "\treturn &waxwingCtx{key: key, handler: handler, outer: outer}"
    , "}"
    , ""
    , "func waxwingFrame(outer *waxwingCtx, key int,"
    , "\tmarker *waxwingMarker) *waxwingCtx {"
    , "\treturn &waxwingCtx{key: key, outer: outer, marker: marker}"
    , "}"
    , ""
    , "func waxwingFind(ctx *waxwingCtx, key int, name string) *waxwingCtx {"
    , "\tfor ctx != nil && ctx.key != key {"
    , "\t\tctx = ctx.outer"
    , "\t}"
    , "\tif ctx == nil {"
    , "\t\tpanic(\"no handler for \" + name)"
    , "\t}"
    , "\treturn ctx"
    , "}"
    , ""
    , "func waxwingFail[R any](ctx *waxwingCtx, key int, payload any,"
    , "\treport func(any) string) R {"
    , "\tframe := waxwingFind(ctx, key, \"Fail\")"
    , "\tpanic(&waxwingAbort{target: frame.marker, payload: payload,"
    , "\t\treport: report})"
    , "}"
    , ""
    , "func waxwingOwns(markers []*waxwingMarker, target *waxwingMarker) bool {"
    , "\tfor _, marker := range markers {"
    , "\t\tif marker == target {"
    , "\t\t\treturn true"
    , "\t\t}"
    , "\t}"
    , "\treturn false"
    , "}"
    , ""
    , "func waxwingHandle[R any](markers []*waxwingMarker, inner *waxwingCtx,"
    , "\tbody func(*waxwingCtx) R) (result R, caught *waxwingAbort) {"
    , "\tdefer func() {"
    , "\t\tif r := recover(); r != nil {"
    , "\t\t\tabort, ok := r.(*waxwingAbort)"
    , "\t\t\tif ok && waxwingOwns(markers, abort.target) {"
    , "\t\t\t\tcaught = abort"
    , "\t\t\t\treturn"
    , "\t\t\t}"
    , "\t\t\tpanic(r)"
    , "\t\t}"
    , "\t}()"
    , "\treturn body(inner), nil"
    , "}"
    ]
    <> "\n\n"
