---
title: docs-manager onboard — non-markdown sources and links that onboard does not rewrite
status: completed
type: tech-debt
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | survey.sh onboard path read |
| 20 | Requirements | done | fix where cheap and safe, report otherwise |
| 30 | Assessment | done | .txt → .md fix; .rst/.adoc conversion unsafe in awk → report; non-md links unparseable → report |
| 40 | POC | skipped | — |
| 50 | Domain | skipped | — |
| 60 | Architecture | done | moved_to resolves folders; report_mentions one awk pass |
| 70 | Tests | done | onboard.test.sh N1–N5, red first (5 failed) |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | survey.sh; host 34/34, bash:5 31 + 1 skipped (git) |
| 100 | Tech Debt | done | none new |
| 110 | Reflection | done | how-to-onboard.md, docs-manager CLAUDE.md |

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

## Result (2026-10-24)

1. A `.txt` doc moves as `.md` and gets frontmatter (N1, N2). An `.rst` or `.adoc` moved into
   `docs/` gets `REVIEW: <doc> is not markdown: …` (N3). Converting those formats in awk would be
   lossy.
2. A link to a moved folder is re-pointed at the folder most of its files went to; a trailing `/`
   is kept, and a tie leaves the link alone (N4).
3. A non-markdown text file that names a moved file by its old path gets
   `REVIEW: <file> names <old>, now <new>` (N5). It is reported, not rewritten: these are not links
   this plugin can parse.

Released in docs-manager 1.10.0.
