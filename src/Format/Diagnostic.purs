module Format.Diagnostic (WireDiagnostic, Response, codeName) where

import Domain.Syntax (ErrorCode(..), Span)

type WireDiagnostic = { code ∷ String, message ∷ String, span ∷ Span }
type Response =
  { ok ∷ Boolean, go ∷ String, diagnostics ∷ Array WireDiagnostic }

codeName ∷ ErrorCode → String
codeName = case _ of
  LexError → "E_LEX"
  SyntaxError → "E_SYNTAX"
  IntegerRange → "E_INTEGER"
  EntryError → "E_ENTRY"
  DuplicateName → "E_DUPLICATE"
  UnboundName → "E_UNBOUND"
  NotCallable → "E_NOT_CALLABLE"
  TypeMismatch → "E_TYPE"
  InternalError → "E_INTERNAL"
  ArityMismatch → "E_ARITY"
  Redundant → "E_REDUNDANT"
  NonExhaustive → "E_NON_EXHAUSTIVE"
