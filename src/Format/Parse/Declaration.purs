module Format.Parse.Declaration (typeDeclaration) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Domain.Syntax (CtorDecl, TypeDecl, TypeRef)
import Format.Parse.Core (Parser, expect, peek, typeRef, upperName)

typeDeclaration ∷ Parser TypeDecl
typeDeclaration state = do
  keyword ← expect "type" state
  identifier ← upperName keyword.rest
  equals ← expect "=" identifier.rest
  constructors ← constructorList equals.rest
  semicolon ← expect ";" constructors.rest
  pure
    { value:
        { name: identifier.value.text
        , ctors: constructors.value
        , span:
            { start: keyword.value.span.start, end: semicolon.value.span.end }
        }
    , rest: semicolon.rest
    }

constructorList ∷ Parser (Array CtorDecl)
constructorList state = do
  first ← constructor state
  remaining ← constructorTail first.rest
  pure { value: Array.cons first.value remaining.value, rest: remaining.rest }

constructorTail ∷ Parser (Array CtorDecl)
constructorTail state =
  if peek state /= "|" then Right { value: [], rest: state }
  else afterBar state

afterBar ∷ Parser (Array CtorDecl)
afterBar state = do
  bar ← expect "|" state
  constructorList bar.rest

constructor ∷ Parser CtorDecl
constructor state = do
  identifier ← upperName state
  if peek identifier.rest == "(" then payload identifier
  else pure (bare identifier)
  where
  bare identifier =
    { value:
        { name: identifier.value.text
        , fields: []
        , span: identifier.value.span
        }
    , rest: identifier.rest
    }
  payload identifier = do
    open ← expect "(" identifier.rest
    fields ← fieldList open.rest
    close ← expect ")" fields.rest
    pure
      { value:
          { name: identifier.value.text
          , fields: fields.value
          , span:
              { start: identifier.value.span.start
              , end: close.value.span.end
              }
          }
      , rest: close.rest
      }

-- A payload constructor needs at least one field; `A()` is rejected at `)`.
fieldList ∷ Parser (Array TypeRef)
fieldList state = do
  first ← typeRef state
  remaining ← fieldTail first.rest
  pure { value: Array.cons first.value remaining.value, rest: remaining.rest }

fieldTail ∷ Parser (Array TypeRef)
fieldTail state =
  if peek state /= "," then Right { value: [], rest: state }
  else afterComma state

afterComma ∷ Parser (Array TypeRef)
afterComma state = do
  comma ← expect "," state
  fieldList comma.rest
