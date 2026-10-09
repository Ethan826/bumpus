module Features.Resolve.Block (Scoped, block) where

import Prelude
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Domain.Resolved as Resolved
import Domain.Syntax as Syntax
import Features.Resolve.Fresh (Fresh, fresh, thread)

-- What a block reads and extends: the locals in scope, by name.
type Scoped r = (locals ∷ Map String Resolved.LocalId | r)

type Resolving r = { | Scoped r } → Syntax.Expr → Fresh Resolved.Expr

type Step r = { value ∷ Resolved.Item, state ∷ { | Scoped r } }

-- FX001 design §1: the items in order, then the value. A `let` is in
-- scope for the items after it and for the value, never for its own
-- expression, and shadows as a match binder does. Its LocalId is taken
-- before its expression's binders (source pre-order); `_` takes none.
block
  ∷ ∀ r
  . Resolving r
  → { | Scoped r }
  → Syntax.Span
  → Array Syntax.Item
  → Syntax.Expr
  → Fresh Resolved.Expr
block expression scope span items value = do
  resolved ← thread (item expression) scope items
  Resolved.Block span resolved.value <$> expression resolved.state value

item ∷ ∀ r. Resolving r → { | Scoped r } → Syntax.Item → Fresh (Step r)
item expression scope = case _ of
  Syntax.Discard value → discarded <$> expression scope value
  Syntax.Let span name value → bound span name <$> traverse issue name
    <*> expression scope value
  where
  discarded resolved = { value: Resolved.Discard resolved, state: scope }
  issue _ = fresh
  bound span name id resolved =
    { value: Resolved.Let span id resolved
    , state: maybe scope (extended scope) (Tuple <$> name <*> id)
    }

extended
  ∷ ∀ r. { | Scoped r } → Tuple String Resolved.LocalId → { | Scoped r }
extended scope (Tuple name id) =
  scope { locals = Map.insert name id scope.locals }
