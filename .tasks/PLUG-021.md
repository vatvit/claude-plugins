---
title: docs-manager external docs — flag related docs when a source changes
status: completed
type: feature
priority: medium
epic: external-docs
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | link parsing lived only inside cmd_links |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | see Assessment |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | R1–R2 in external.test.sh, 73/73 host + container |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | doc_links, external related, REVIEW lines, relates-to link check, how-to section |
| 100 | Tech Debt | done | none from this task; PLUG-022 found while working it |
| 110 | Reflection | done | docs-manager CLAUDE.md: doc_links + dependant rule |

## Description

When a card is reported **changed** (sub-task PLUG-018), list the project docs in its
`relates-to:` — and any doc linking to the card or binary — as "review needed". The skill
then proposes concrete updates; project docs cite card locations rather than copying text.

## Acceptance criteria

1. `docs.sh check` output for a changed source includes its related docs.
2. Back-links (docs linking the card/binary) are found without a second link parser.
3. Skill section on refreshing docs from a changed source; user approves each edit.
4. Tests; host + container.

## Assessment (2026-10-08)

- Markdown links were parsed only inside `cmd_links` (`grep -oE '\]\([^)]+\)'`), and `external move`
  scraped `cmd_links`' text output. AC2 ("no second link parser") meant extracting that parser.
- Every folder's generated `_index.md` links each card, so a naive back-link search lists it under
  every change. It has to be excluded.

## Architecture

- `lib.sh: doc_links <root>` emits `file<TAB>link<TAB>target` records with normalized paths. It is
  the only link parser: `cmd_links` reads it, and so does `external_related`.
- `external_related <file> <links-file>` emits `relates-to<TAB>doc` (from the card, card-relative)
  and then `links<TAB>doc` (links to the card or the file), with the card itself and `_index.md`
  excluded and each doc listed once.
- `external check` parses the links once, lazily, the first time it finds a CHANGED file, and
  prints `  REVIEW: <doc> (<kind>)` under each CHANGED line (AC1). There is also a standalone
  `docs.sh external related <file-or-card> [root]`.
- A `relates-to:` entry pointing at a missing doc is reported by `links` as `BROKEN REF: <card> ->
  relates-to:<path>` (a third pass), so each breakage is reported in one place.
- Skill (AC3): a new how-to section, "Refreshing docs from a changed source". Re-card first, then
  go doc by doc, propose edits and apply each only after the user approves it. Cite the card,
  never copy the text.
- Side effect: BROKEN LINK paths are now normalized (`docs//a.md` becomes `docs/a.md`), and
  `move` compares against the normalized card path.

## Current State (2026-10-08)

Completed. docs-manager 1.7.0 (shared with PLUG-020), not committed. Suites: external 73/73 and
diagram 100/100 on host, container and a standalone copy.
