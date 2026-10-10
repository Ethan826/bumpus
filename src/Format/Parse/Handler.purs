module Format.Parse.Handler
  ( handlerExpr
  , withExpr
  , handleExpr
  , failExpr
  , unsupportedControl
  ) where

import Prelude
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Domain.Problem (Problem(..))
import Domain.Syntax
  ( Clause
  , Expr(..)
  , FailClause
  , Span
  , exprSpan
  , problemAt
  )
import Format.Parse.Grammar
  ( Parser
  , commaList
  , dispatch
  , expect
  , name
  , on
  , refine
  , sepByTrailing1
  , spanned
  , token
  )
import Format.Parse.Row (label)
import Format.Parse.Type (typeRef)

type Binder = { name ∷ Maybe String, span ∷ Span }

handlerExpr ∷ Parser Expr → Parser Expr
handlerExpr inner = make <$> expect "handler" <*> label typeRef
  <* expect "{"
  <*> clauses (clause inner)
  <*> expect "}"
  where
  make keyword effect found close = HandlerExpr
    { start: keyword.span.start, end: close.span.end }
    effect
    found

withExpr ∷ Parser Expr → Parser Expr
withExpr inner = scoped <$> expect "with" <*> inner <*> inner
  where
  scoped keyword handler body = With
    { start: keyword.span.start, end: (exprSpan body).end }
    handler
    body

handleExpr ∷ Parser Expr → Parser Expr
handleExpr inner = handled <$> expect "handle" <*> inner <* expect "{"
  <*> clauses (failureClause inner)
  <*> expect "}"
  where
  handled keyword body found close = Handle
    { start: keyword.span.start, end: close.span.end }
    body
    found

clauses ∷ ∀ a. Parser a → Parser (Array a)
clauses item = dispatch [ on "}" (pure []) ]
  (sepByTrailing1 "," "}" item)

failExpr ∷ Parser Expr → Parser Expr
failExpr inner = failed <$> expect "fail" <* expect "(" <*> inner
  <* expect ")"
  where
  failed keyword value = Fail
    { start: keyword.span.start, end: (exprSpan value).end }
    value

unsupportedControl ∷ Parser Expr
unsupportedControl = refine rejected token
  where
  rejected found = Left
    ( problemAt
        (Syntax "General control (ctl/resume) is not supported yet")
        found.span
    )

clause ∷ Parser Expr → Parser Clause
clause inner = spanned build
  ( parts <$> name <* expect "(" <*> commaList binder <* expect ")"
      <* expect "=>"
      <*> inner
  )
  where
  parts identifier parameters body =
    { name: identifier.text, parameters, body }
  build span found =
    { name: found.name, parameters: found.parameters, body: found.body, span }

failureClause ∷ Parser Expr → Parser FailClause
failureClause inner = spanned build
  ( parts <$> expect "fail" <* expect "(" <*> name <* expect ":"
      <*> typeRef
      <* expect ")"
      <* expect "=>"
      <*> inner
  )
  where
  parts _ error errorType body = { name: error.text, ty: errorType, body }
  build span found =
    { name: found.name, ty: found.ty, body: found.body, span }

binder ∷ Parser Binder
binder = spanned build
  (dispatch [ on "_" (Nothing <$ token) ] (Just <<< textOf <$> name))
  where
  build span found = { name: found, span }
  textOf found = found.text

