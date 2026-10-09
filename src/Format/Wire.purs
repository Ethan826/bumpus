-- The plain records the CLI writes to stderr. Runtime only serializes them.
module Format.Wire
  ( WireRecord(..)
  , PlainRecord
  , SourceRecord
  , ToolRecord
  , usageRecord
  , failureRecord
  , sourceRecord
  ) where

import Domain.Host (HostFailure(..))
import Domain.Syntax (Diagnostic, Note, Span)
import Format.Diagnostic (wire)

type PlainRecord = { code ∷ String, message ∷ String }
type SourceRecord =
  { code ∷ String
  , message ∷ String
  , span ∷ Span
  , file ∷ String
  , related ∷ Array Note
  }

type ToolRecord =
  { ok ∷ Boolean, code ∷ String, message ∷ String, command ∷ String }

-- Three shapes, because the CLI's usage/IO, source and tool failures have
-- always carried different fields; one record type would add or drop some.
data WireRecord
  = PlainWire PlainRecord
  | SourceWire SourceRecord
  | ToolWire ToolRecord

usageRecord ∷ String → WireRecord
usageRecord text = PlainWire { code: "E_USAGE", message: text }

failureRecord ∷ HostFailure → WireRecord
failureRecord = case _ of
  IoFailure text → PlainWire { code: "E_IO", message: text }
  ToolFailure tool → ToolWire
    { ok: false, code: "E_TOOL", message: tool.message, command: tool.command }

sourceRecord ∷ String → Diagnostic → WireRecord
sourceRecord file diagnostic = SourceWire
  { code: rendered.code
  , message: rendered.message
  , span: rendered.span
  , file
  , related: rendered.related
  }
  where
  rendered = wire diagnostic
