---
title: docs-manager onboard — non-markdown sources and links that onboard does not rewrite
status: proposed
type: tech-debt
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

Shortcuts taken in PLUG-071 (docs-manager 1.9.0, `survey` / `onboard`), each one a case where the
result needs a manual fix today:

1. **`.rst`, `.adoc`, `.txt` moved into `docs/`** keep their extension: no frontmatter is added and
   `index` lists only `*.md`, so they are invisible in the `_index.md` listings. Options: convert on
   move (a `.txt` reads as markdown as is; `.rst`/`.adoc` do not), or list them as non-markdown docs.
2. **A link to a moved folder** (`[docs](doc/)`) is not rewritten; only links to files are.
3. **Links from non-markdown files** (code comments, `.rst`, HTML) to a moved doc are not rewritten
   and not reported.

## Acceptance criteria

- Each case has a test in `docs-manager/scripts/test/onboard.test.sh`, red before the change.
- Or the case is reported by `onboard` (a `REVIEW:` line naming the file) when fixing it is not worth it.

## Current State

Proposed (from PLUG-071's tech-debt step). Not started.