module Features.Check.Operation
  ( operationCall
  , operationRef
  , printCall
  , printRef
  , crashCall
  , crashRef
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Ids (EffectId(..))
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..), openRow)
import Domain.Syntax (Diagnostic, Span, Sort(..), problemAt)
import Domain.Type (Ty(..), TyRow, VarId(..))
import Features.Check.Call (named)
import Features.Check.Consume (consumeAt)
import Features.Check.Context (CheckEnv, Infer)
import Features.Check.Scheme (State, Threaded)
import Features.Check.Stages (arrowType)
import Features.Check.Provenance (Consumed(Operation))
import Features.Check.Use (Use, declarationUse, withOrigin)

type Result = Either Diagnostic (Threaded Checked.Expr)

operationCall
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → State
  → Span
  → EffectId
  → Int
  → Array Resolved.Expr
  → Result
operationCall infer env state span effect index arguments = do
  use ← operationUse env state span effect index
  named infer env span (Checked.Perform effect index) use arguments

operationRef ∷ ∀ r. CheckEnv r → State → Span → EffectId → Int → Result
operationRef env state span effect index = do
  use ← operationUse env state span effect index
  pure
    { value: Checked.Expr
        { ty: arrowType use.value.fields use.value.rows use.value.result
        , span
        , node: Checked.OperationRef effect index use.value.scheme.arguments
        }
    , state: use.state
    }

printCall
  ∷ ∀ r. Infer r → CheckEnv r → State → Span → Array Resolved.Expr → Result
printCall infer env state span arguments = maybe' arity found
  (Array.head arguments)
  where
  arity _ = Left (problemAt Arity span)
  found argument
    | Array.length arguments /= 1 = arity unit
    | otherwise = do
        checked ← infer env state argument
        consumed ← consumeAt env checked.state span (Operation "print") console
        pure
          { value: Checked.Expr
              { ty: TUnit
              , span
              , node: Checked.Print checked.value
              }
          , state: consumed
          }

-- A builtin reference is a monomorphic lambda at each fresh use. Print's
-- admissibility is checked after the body's ordinary type constraints.
printRef ∷ ∀ r. CheckEnv r → State → Span → Result
printRef _ state span = Right
  { value: Checked.Expr
      { ty: TFun parameter console TUnit
      , span
      , node: Checked.Lambda [ { local: Just local, ty: parameter } ] body
      }
  , state: state { next = state.next + 1 }
  }
  where
  parameter = TVar (Hole state.next)
  local = Resolved.LocalId (-1)
  body = Checked.Expr { ty: TUnit, span, node: Checked.Print value }
  value = Checked.Expr { ty: parameter, span, node: Checked.Local local }

-- `crash(value)` performs nothing and never returns, so its result is a
-- fresh type; `with pure` promises neither (FX001 design §3). Its argument
-- is judged printable after the body's other constraints, with `print`'s.
crashCall
  ∷ ∀ r. Infer r → CheckEnv r → State → Span → Array Resolved.Expr → Result
crashCall infer env state span arguments = maybe' arity found
  (Array.head arguments)
  where
  arity _ = Left (problemAt Arity span)
  found argument
    | Array.length arguments /= 1 = arity unit
    | otherwise = do
        checked ← infer env state argument
        pure
          { value: Checked.Expr
              { ty: TVar (Hole checked.state.next)
              , span
              , node: Checked.Crash checked.value
              }
          , state: checked.state { next = checked.state.next + 1 }
          }

-- Bare `crash` is a monomorphic lambda at each use, as `print` is, over a
-- fresh parameter, result and row.
crashRef ∷ ∀ r. CheckEnv r → State → Span → Result
crashRef _ state span = Right
  { value: Checked.Expr
      { ty: TFun parameter (openRow (Hole (state.next + 2))) result
      , span
      , node: Checked.Lambda [ { local: Just local, ty: parameter } ] body
      }
  , state: state { next = state.next + 3 }
  }
  where
  parameter = TVar (Hole state.next)
  result = TVar (Hole (state.next + 1))
  local = Resolved.LocalId (-1)
  body = Checked.Expr { ty: result, span, node: Checked.Crash value }
  value = Checked.Expr { ty: parameter, span, node: Checked.Local local }

console ∷ TyRow Open
console = Row [ Label ConsoleEffect [] ] Nothing

operationUse
  ∷ ∀ r
  . CheckEnv r
  → State
  → Span
  → EffectId
  → Int
  → Either Diagnostic (Threaded Use)
operationUse env state span effect@(EffectId owner) index =
  maybe' missing owned (Array.index env.effects owner)
  where
  missing _ = Left (problemAt (Internal "Invalid operation") span)
  owned info = maybe' missing (used info)
    (Array.index info.operations index)
  used info operation = Right
    ( withOrigin (Operation operation.name) Nothing
        ( declarationUse state info.parameters
            (map typeSort info.parameters)
            (map parameterType operation.parameters)
            operation.result
            ( Row
                [ Label (UserEffect effect)
                    (Array.mapWithIndex variable info.parameters)
                ]
                Nothing
            )
        )
    )
  typeSort _ = TypeSort
  parameterType parameter = parameter.ty
  variable position _ = TVar (VarId position)
