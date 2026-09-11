---
title: Typed refs — resolution, References line, link checking
status: proposed
type: feature
priority: high
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | — | |
| 20 | Assessment | — | |
| 30 | POC | — | |
| 40 | Domain | — | |
| 50 | Architecture | — | |
| 60 | Tests | — | |
| 70 | Subtasks | — | |
| 80 | Implementation | — | |
| 90 | Tech Debt | — | |
| 100 | Reflection | — | |

## Description

A diagram becomes navigable: each node can point at a file, doc, task, glossary term,
url or another diagram, rendered as a caption list under the fence and validated by
the existing link checker.

**Full spec in PLUG-001** (R9–R11; Domain "ref"; Tests cases 6–9).

## Scope

- ref schemes `file:` `doc:` `task:` `term:` `url:` `diagram:`
- resolver → href relative to **each** embedding doc (a source with two embeds at
  different depths yields different hrefs — case 7)
- `**References**` line inside the generated block, author order preserved
- extend `cmd_links` to crawl `refs:` in every `*.diagram.md`
- `url:` emitted but never resolved, never fetched

## Depends on

PLUG-002 (needs `fm_parse` map records and the generated block).
Independent of the staleness and rendering slices — can run in parallel with both.

## Acceptance

Cases 6–9 pass on both targets.
