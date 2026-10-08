---
title: docs-manager external docs — docx/xlsx extraction with fallback
status: completed
type: feature
priority: medium
epic: external-docs
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | epic + external.sh read; unzip present on macOS and busybox |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | see Assessment |
| 40 | POC | done | unzip -p + awk works on both targets (AC3) — adopted |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | X1–X4 in external.test.sh, 73/73 host + container |
| 80 | Subtasks | skipped | one script, one session |
| 90 | Implementation | done | extract.sh, docs.sh/external.sh wiring, how-to, README, 1.7.0 |
| 100 | Tech Debt | done | PLUG-023 (pptx/ODF), PLUG-024 (real-file check) |
| 110 | Reflection | done | docs-manager CLAUDE.md: extract.sh section, fixtures note |

## Description

docx / xlsx (and doc / xls) cannot be read natively. Extract text / sheet structure using
tools only if present (e.g. pandoc, libreoffice, unzip+awk on OOXML), optionally in docker
with explicit user approval; otherwise fall back to a minimal card (`description` from the
user, `## Where to look` marked TODO). Never install anything.

## Acceptance criteria

1. Tool detection is one function; absence yields the fallback, not an error.
2. xlsx card lists sheet names and header columns; docx card lists headings.
3. Pure unzip+awk path for OOXML evaluated in POC — adopt if it covers 2 without extra tools.
4. Tests with tiny fixture files; host + container.

## Assessment (2026-10-08)

- docx/xlsx are zip packages of XML. `unzip` ships with macOS (`/usr/bin/unzip`) and busybox
  (`bash:5` image), so nothing has to be installed and no container is needed.
- Portability found in the POC: on a missing member Info-ZIP prints "caution: filename not
  matched" and exits 11, while busybox exits 0 silently. "Empty output" is therefore the only
  portable test.
- busybox has no `zip`, so the suite cannot build fixtures in the container. They are committed.

## Architecture

- New `scripts/extract.sh`, sourced by `docs.sh`. Commands: `docs.sh external outline|text <file-or-card>`.
- `extract_kind` is the one capability check (AC1). pdf, doc/xls/ppt, other formats, no `unzip`
  and an unreadable package all give `none<TAB>reason` with exit 0. Only a missing file is an error.
- awk with `RS="<"`, one tag per record. Helpers live in one shared `AWK_XML` prelude (tag,
  local name, attr, entity decoding). Two parts go through one awk pass, joined by a sentinel
  record, because `FNR==NR` breaks when the optional first part is empty.
- docx heading level: the paragraph's own `outlineLvl`, else its style's (by name `heading N`,
  `Title` = 1, or the style's `outlineLvl`), else a `HeadingN` style id when `styles.xml` is absent.
- xlsx: sheets come in workbook order via the rels (never by file name). Shared strings handle
  rich text and skip `rPh`; inline strings are read; cells are placed by `r` so sparse rows keep
  their columns; namespace prefixes are ignored; sheet names reach awk via `ENVIRON`.
- The card is still written by the agent from `outline`, plus `text` saved to a temp dir. The
  script never writes.

## Current State (2026-10-08)

Completed. docs-manager 1.7.0 (shared with PLUG-021), not committed. Suites: external 73/73 and
diagram 100/100 on host, container and a standalone copy. Follow-ups: PLUG-023 and PLUG-024.
