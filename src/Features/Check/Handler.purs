module Features.Check.Handler (handler, withHandler, handleFailure) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl, foldr)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe, maybe')
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Ids (EffectId(..))
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..), closedRow)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TyRow, VarId(..), substitute)
import Features.Check.Context (CheckEnv, Infer, Locals)
import Features.Check.Consume (consumeAt)
import Features.Check.Require (require, typeName)
import Features.Check.Scheme (State, Threaded, headOf, threadAll)

type HandlerEnv r = CheckEnv (locals ∷ Locals | r)
type Checked = Either Diagnostic (Threaded Checked.Expr)

handler
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → HandlerEnv r
  → State
  → Span
  → Label (Ty Resolved.VarId)
  → Array Resolved.HandlerClause
  → Checked
handler infer env state span label clauses = do
  let row = Row [] (Just (Hole state.next))
  checked ← threadAll (handlerClause infer env row label)
    (state { next = state.next + 1 })
    clauses
  pure
    { value: Checked.Expr
        { ty: THandler (openLabel label) row
        , span
        , node: Checked.Handler (effectId label) (labelArgs label)
            checked.value
        }
    , state: checked.state
    }

handlerClause
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → HandlerEnv r
  → TyRow Open
  → Label (Ty Resolved.VarId)
  → State
  → Resolved.HandlerClause
  → Either Diagnostic { value ∷ Checked.HandlerClause, state ∷ State }
handlerClause
  infer
  env
  row
  label
  state
  (clause ∷ Resolved.HandlerClause) = do
  let checkedParameters = map (typedParameter label) clause.parameters
  let
    scoped = env
      { current = row
      , locals = bindParameters checkedParameters env.locals
      }
  checkedBody ← inferHandlerBody infer scoped state clause.body
  reached ← require scoped checkedBody.state
    (instantiateType label clause.result)
    checkedBody.value
  pure
    { value:
        { operation: clause.operation
        , parameters: checkedParameters
        , body: checkedBody.value
        , span: clause.span
        }
    , state: reached
    }
  where
  typedParameter effectLabel found =
    { local: found.local, ty: instantiateType effectLabel found.ty }
  bindParameters parameters locals =
    foldl insertParameter locals parameters
  insertParameter locals entry = maybe locals (insertLocal entry locals)
    entry.local
  insertLocal entry locals local = Map.insert local entry.ty locals

inferHandlerBody
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → HandlerEnv r
  → State
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
inferHandlerBody infer env state body = infer env state body

withHandler
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → HandlerEnv r
  → State
  → Span
  → Resolved.Expr
  → Resolved.Expr
  → Checked
withHandler infer env state span handlerExpr body = do
  handlerValue ← infer env state handlerExpr
  case headOf handlerValue.state (Checked.typeOf handlerValue.value) of
    THandler label row → withValue handlerValue label row
    other → expectedHandler env span other
  where
  withValue handlerValue label row = do
    consumed ← consumeAt env handlerValue.state span row
    bodyValue ← infer (env { current = prepend label env.current }) consumed
      body
    pure
      { value: Checked.Expr
          { ty: Checked.typeOf bodyValue.value
          , span
          , node: Checked.With handlerValue.value bodyValue.value
          }
      , state: bodyValue.state
      }

handleFailure
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → HandlerEnv r
  → State
  → Span
  → Resolved.Expr
  → Array Resolved.FailClause
  → Checked
handleFailure infer env state span body clauses = do
  bodyValue ← infer (env { current = withFailures clauses env.current }) state
    body
  finished ← threadAll
    (failureClause infer env (Checked.typeOf bodyValue.value))
    bodyValue.state
    clauses
  pure
    { value: Checked.Expr
        { ty: Checked.typeOf bodyValue.value
        , span
        , node: Checked.Handle bodyValue.value finished.value
        }
    , state: finished.state
    }

failureClause
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → HandlerEnv r
  → Ty Open
  → State
  → Resolved.FailClause
  → Either Diagnostic { value ∷ Checked.FailClause, state ∷ State }
failureClause infer env expected state clause = do
  local ← maybe' invalid Right clause.local
  let payload = map Rigid (payloadType clause.label)
  let scoped = env { locals = Map.insert local payload env.locals }
  body ← infer scoped state clause.body
  reached ← require scoped body.state expected body.value
  pure
    { value: { payload, local, body: body.value, span: clause.span }
    , state: reached
    }
  where
  invalid _ = Left (problemAt (Internal "Missing fail binder") clause.span)

expectedHandler ∷ ∀ r. HandlerEnv r → Span → Ty Open → Checked
expectedHandler env span ty = do
  name ← typeName env span ty
  Left (problemAt (ExpectedHandler name) span)

instantiateType ∷ Label (Ty Resolved.VarId) → Ty Resolved.VarId → Ty Open
instantiateType label = substitute
  { types: argument (labelArgs label)
  , rows: closed
  }
  where
  closed _ = closedRow

argument ∷ Array (Ty Open) → VarId → Ty Open
argument args (VarId index) = maybe (TVar (Rigid (VarId index))) identity
  (Array.index args index)

labelArgs ∷ Label (Ty Resolved.VarId) → Checked.Instantiation
labelArgs (Label _ args) = map (map Rigid) args

openLabel ∷ Label (Ty Resolved.VarId) → Label (Ty Open)
openLabel (Label effect args) = Label effect (map (map Rigid) args)

effectId ∷ Label (Ty Resolved.VarId) → EffectId
effectId (Label (UserEffect id) _) = id
effectId _ = EffectId (-1)

payloadType ∷ Label (Ty Resolved.VarId) → Ty Resolved.VarId
payloadType (Label _ arguments) = maybe' noPayload identity
  (Array.head arguments)
  where
  noPayload _ = TUnit

prepend ∷ Label (Ty Open) → TyRow Open → TyRow Open
prepend label (Row labels tail) = Row (Array.cons label labels) tail

withFailures ∷ Array Resolved.FailClause → TyRow Open → TyRow Open
withFailures clauses row = foldr add row clauses
  where
  add clause (Row labels tail) =
    Row (Array.cons (openLabel clause.label) labels) tail
