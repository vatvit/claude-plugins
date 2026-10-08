---
title: docs-manager external docs — outline/text for pptx and OpenDocument (odt, ods, odp)
status: proposed
type: feature
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

`docs.sh external outline|text` (PLUG-020) reads docx and xlsx with `unzip -p` + awk; every other
format falls back to a `none` record. pptx and the OpenDocument formats are also zip packages of
XML, so the same path should cover them: pptx slide titles (`ppt/slides/slideN.xml`, title
placeholder, in `presentation.xml` order), odt headings (`content.xml`, `text:h` with
`text:outline-level`), ods sheets (`table:table` name + first row), odp slide names.

## Acceptance criteria

1. `outline` for pptx/odp lists slides by number with their titles; odt lists headings; ods lists
   sheets with header columns — same record shapes as docx/xlsx.
2. `extract_kind` stays the single capability check; unreadable packages still give `none`.
3. Fixtures built by `scripts/test/fixtures/build.sh`; host + container.
