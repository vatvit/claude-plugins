---
title: crew — work in a copy, land with merge-or-refuse apply
status: proposed
type: feature
epic: crew
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

Unfinished or failing work stays out of the shared tree (playbook §3, §9.4). A session works
in a copy and lands it with a merge-or-refuse apply.

- `copy.sh new <dir> [--at <commit>]` creates a copy of the tree at a named commit (a
  scratchpad or container path) and records its base. `copy.sh rebase <dir>` moves the copy
  onto the commit the shared tree is on now, with the same take / merge / refuse rules.
- `apply.sh <dir> [paths…]`, for each file changed in the copy:
  - **take** when the tree still matches the base;
  - **3-way merge** (`git merge-file`) when a peer changed it;
  - **refuse** on a conflict, naming the file.

  Nothing lands unless every file is clean. The summary line is "apply: N taken, M merged,
  K refused".
- Optional `landCheck` command in `.crew.json` (e.g. a formatter check), run on the landed
  file list. If it fails, the apply is refused and the tree is left untouched.
- `references/copy-apply.md`.

## Acceptance criteria

- [ ] An untouched base gives *taken*. A peer edit in another hunk gives *merged*, with both
      edits present.
- [ ] A conflicting peer edit gives *refused*, names the file, and leaves the tree
      byte-identical.
- [ ] A copy based on an older commit and rebased onto HEAD applies cleanly.
- [ ] A failing `landCheck` refuses the whole apply.
- [ ] Added and deleted files are handled. Paths with spaces work.
- [ ] The suite passes in docker and from a standalone copy.
