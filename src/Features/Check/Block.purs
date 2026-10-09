module Features.Check.Block (checkBlock) where

import Prelude
import Data.Either (Either)
import Data.Map as Map
import Data.Maybe (Maybe, maybe)
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Resolved (LocalId)
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span)
import Domain.Type (Ty)
import Features.Check.Context (CheckEnv, Infer, Locals)
import Features.Check.Defer (checkDefer)
import Features.Check.Scheme (State, Threaded, threadAll)

type BlockEnv r = CheckEnv (locals ∷ Locals | r)

-- What threads through a block's items: the checking state, and the
-- locals the items so far have bound.
type Scope = { state ∷ State, locals ∷ Locals }

type Checked a = Either Diagnostic a

-- FX001 design §2: the items in order, then the value, whose type is the
-- block's. `let x = e` binds x at e's type, monomorphically: nothing is
-- generalized, so a let-bound lambda's metas are fixed by its uses. A
-- discarded item may have any type; a deferred one is Unit and cannot fail
-- (Features.Check.Defer). The threading is Scheme `threadAll`, so a block
-- of 20,000 items costs no frame per item.
checkBlock
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → BlockEnv r
  → State
  → Span
  → Array Resolved.Item
  → Resolved.Expr
  → Checked (Threaded Checked.Expr)
checkBlock infer env state span items value = do
  threaded ← threadAll (item infer env) { state, locals: env.locals } items
  result ← infer (env { locals = threaded.state.locals }) threaded.state.state
    value
  pure
    { value: Checked.Expr
        { ty: Checked.typeOf result.value
        , span
        , node: Checked.Block threaded.value result.value
        }
    , state: result.state
    }

item
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → BlockEnv r
  → Scope
  → Resolved.Item
  → Checked { value ∷ Checked.Item, state ∷ Scope }
item infer env scope = case _ of
  Resolved.Discard value → discarded <$> inferred value
  Resolved.Let _ local value → bound local <$> inferred value
  Resolved.Defer span value → deferred <$> checkDefer infer
    (env { locals = scope.locals })
    scope.state
    span
    value
  where
  deferred checked =
    { value: Checked.Defer checked.value
    , state: scope { state = checked.state }
    }
  inferred = infer (env { locals = scope.locals }) scope.state
  discarded checked =
    { value: Checked.Discard checked.value
    , state: scope { state = checked.state }
    }
  bound local checked =
    { value: Checked.Let local checked.value
    , state:
        { state: checked.state
        , locals: withLocal local (Checked.typeOf checked.value) scope.locals
        }
    }

withLocal ∷ Maybe LocalId → Ty Open → Locals → Locals
withLocal local ty locals = maybe locals added local
  where
  added id = Map.insert id ty locals
