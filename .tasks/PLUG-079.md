---
title: docs-manager — index and check skip .git and other dot-folders
status: completed
type: bug
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | ten bare find walks across docs.sh, lib.sh, diagram.sh, external.sh |
| 20 | Requirements | done | the acceptance criteria |
| 30 | Assessment | done | no index/check suite of its own; external.test.sh has the index cases |
| 40 | POC | skipped | small fix |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | one docs_find helper, every walk through it |
| 70 | Tests | done | external.test.sh D1/D2, 9 red before the fix |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | below; docs-manager 1.8.0 -> 1.8.1 |
| 100 | Tech Debt | done | none new |
| 110 | Reflection | done | CLAUDE.md rule; memory: no git stash in a shared tree |

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

## Implementation

- `lib.sh`: `docs_find <root> <maxdepth|""> <tests…>` — `find root -mindepth 1 [-maxdepth N]
  -name '.*' -prune -o \( tests -print \)`. `-mindepth 1` keeps a dot-named root (`.site-docs`)
  walkable; callers that need the root itself print it (`cmd_index`).
- Routed through it: `list_subdirs`, `list_docs`, `cmd_index`'s folder walk, `cmd_links`' diagram
  pass, `doc_links`, all four walks in `diagram.sh` over the docs root, `list_externals` and
  `list_cards`. Hidden files are skipped too (externals already skipped them; docs did not).
- Left as is: `diagram.sh:123`, the walk of a ref's target folder — usually code, outside the docs
  tree, and its file list feeds blessed digests; pruning there would mark every stamped diagram
  changed.
- Tests: `external.test.sh` D1 (a docs root holding `.git/`, `.obsidian/` with a broken link and a
  stray diagram source, a pdf inside `.git/`, a hidden file) and D2 (a root named `.site-docs`).
  9 checks red before the fix and again with the prune disabled; 91/91 and diagram 100/100 on the
  host and in `bash:5`.
- Docs: SKILL.md convention, README feature line, plugin CLAUDE.md (`docs_find` rule).

## Current State

Completed 2026-10-23. Not committed.
