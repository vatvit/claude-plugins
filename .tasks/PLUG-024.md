---
title: docs-manager external docs — check extract.sh against real Office-produced files
status: proposed
type: chore
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

PLUG-020's fixtures are hand-written minimal OOXML. Real files carry things they do not:
`mc:AlternateContent` (a text box appears twice, Choice + Fallback, so its text is duplicated),
auto-numbered headings (the number lives in `numbering.xml`, so `outline` shows "Scope", not
"4.2 Scope"), styles inheriting a heading level via `w:basedOn`, and numeric entities
(`&#10;`). Run `outline` / `text` over a handful of real documents from Word, LibreOffice and
Google Docs/Sheets exports and fix what is wrong — or record it in the how-to as a known limit.

## Acceptance criteria

1. Each listed construct either handled with a fixture case, or named as a limit in
   `how-to-external-docs.md`.
2. No file that opens in Word/Excel yields an error; worst case is `none`.
