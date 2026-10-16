---
title: crew — status lists the worktrees — task, branch, owner, unmerged commits, lag, uncommitted files
status: approved
type: feature
priority: medium
epic: crew-worktrees
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

Part of PLUG-062 (epic `crew-worktrees`). `crew status` describes one tree today. Work inside a
worktree would be invisible in it.

## Scope

- A new part, `status.d/trees.sh`, so `status.sh` itself is not edited. One line per crew worktree
  under `.worktrees/`:
  - the folder;
  - the task id or copy name;
  - the branch or `detached`;
  - the owner session;
  - commits not yet merged;
  - how far behind the destination it is;
  - its count of uncommitted files.
- Worktrees crew did not make are counted in one line and never listed as crew's.
- Silent when there are no worktrees.

## Acceptance criteria

- In a fixture repo with a detached worktree, a branch worktree and a foreign one, the output
  lists the two crew worktrees with correct counts and counts the foreign one.
- No worktrees: no `trees:` line.

## Notes

- Needs nothing: fixture worktrees can be made directly in the test. It covers PLUG-061's
  "which task is each session on" for sessions working in a worktree.

## Current State

Approved (2026-10-16). Nothing changed in code.
