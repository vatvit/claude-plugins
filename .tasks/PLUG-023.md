---
title: docs-manager external docs — outline/text for pptx and OpenDocument (odt, ods, odp)
status: completed
type: feature
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | extract.sh read; pptx/ODF part layout from the formats |
| 20 | Requirements | done | acceptance criteria as written |
| 30 | Assessment | done | same unzip + awk path; no new dependency |
| 40 | POC | skipped | fixtures were the POC |
| 50 | Domain | skipped | no new concepts |
| 60 | Architecture | done | shared emitters in AWK_XML, AWK_ODF for the three ODF readers, ooxml_order replaces xlsx_sheets |
| 70 | Tests | done | external.test.sh X5–X9, red first (8 failed) |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | extract.sh; host + bash:5 100/100 |
| 100 | Tech Debt | done | none new; PLUG-024 limits table extended for these formats |
| 110 | Reflection | done | docs-manager CLAUDE.md, README, how-to-external-docs updated |

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

## Result (2026-10-24)

- `external outline|text` now reads pptx, odt, ods and odp. Their records have the same shapes as
  docx/xlsx, plus `slide<TAB>n<TAB>title` for the decks. `extract_kind` is still the only
  capability check.
- pptx slides come in show order through `ooxml_order`, which now also orders xlsx sheets.
  `para_emit`, `slide_emit` and `letters` are shared in `AWK_XML`. The ODF readers skip comments,
  footnotes and speaker notes. ods counts LibreOffice's repeated padding and never expands it.
- New fixtures: deck.pptx, deck.odp, notes.odt and sheet.ods, built from `fixtures/src/`. The old
  fixtures rebuild byte-identical.
- Tests: X5–X9 (external 100/100 on the host and in bash:5).
- Released in docs-manager 1.10.0, together with PLUG-059, PLUG-024 (rejected; limits documented)
  and PLUG-083.
