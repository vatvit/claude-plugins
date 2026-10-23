---
title: docs-manager — index and check skip .git and other dot-folders
status: proposed
type: bug
priority: medium
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

When the docs folder is itself a git repository (`git init` inside `docs/`), `docs.sh check docs`
treats `.git/` and every folder under it as a docs sub-folder and fails:

```
MISSING: docs/.git/refs/heads/_index.md
MISSING: docs/.git/_index.md
...
DRIFT: docs/_index.md (run: scripts/docs.sh index --write)
```

`index --write` would presumably write `_index.md` files into `.git/`. Seen with docs-manager 1.8.0.

## Acceptance criteria

- `index` and `check` skip `.git` and every other dot-folder (`.*`) at any depth.
- A test: a fixture docs folder holding a `.git/` subtree passes `check` and gets no index entry or
  `_index.md` for it; seen failing before the fix.

## Current State

Proposed. Not started.
