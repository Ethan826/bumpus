module Format.Parse.Pattern (pattern, arms) where

import Prelude
import Data.Maybe (Maybe, fromMaybe)
import Format.Lex (Token, isName, isUpper)
import Domain.Syntax (Arm, Expr, Pattern(..), Span, exprSpan, patternSpan)
import Format.Parse.Grammar
  ( Parser
  , defer
  , dispatch
  , expect
  , failWith
  , on
  , onWhen
  , optionalOn
  , sepBy1
  , sepByTrailing1
  , spanned
  , token
  , upperName
  )
import Format.Parse.Literal (integerLiteral, integerStart)

-- An upper name is always a constructor and a lower name always a binder,
-- so a misspelled constructor never becomes a catch-all.
pattern ∷ Parser Pattern
pattern = dispatch
  [ on "_" (PWildcard <$> tokenSpan)
  , on "true" (flip PBool true <$> tokenSpan)
  , on "false" (flip PBool false <$> tokenSpan)
  , onWhen integerStart (intPattern <$> integerLiteral)
  , onWhen upperText ctorPattern
  , onWhen isName (binder <$> token)
  ]
  (failWith "Expected a pattern")
  where
  upperText text = isName text && isUpper text
  intPattern literal = PInt literal.span literal.value
  binder found = PBind found.span found.text

-- One or more arms and an optional trailing comma. The closing `}` is left
-- for the caller, whose match span ends there.
arms ∷ Parser Expr → Parser (Array Arm)
arms body = sepByTrailing1 "," "}" (arm body)

tokenSpan ∷ Parser Span
tokenSpan = spanOf <$> token
  where
  spanOf found = found.span

-- Spans the name alone, or through the `)` closing its fields.
ctorPattern ∷ Parser Pattern
ctorPattern = spanned ctorOf (parts <$> upperName <*> optionalOn "(" fields)
  where
  parts identifier found = { identifier, fields: found }
  fields = expect "(" *> sepBy1 "," (defer nested) <* expect ")"
  nested _ = pattern

ctorOf ∷ Span → { identifier ∷ Token, fields ∷ Maybe (Array Pattern) } → Pattern
ctorOf span found =
  PCtor span found.identifier.text (fromMaybe [] found.fields)

-- An arm spans its pattern through its body, whose own span may stop
-- inside closing parentheses.
arm ∷ Parser Expr → Parser Arm
arm body = armOf <$> pattern <* expect "=>" <*> body
  where
  armOf matched result =
    { pattern: matched
    , body: result
    , span: { start: (patternSpan matched).start, end: (exprSpan result).end }
    }
