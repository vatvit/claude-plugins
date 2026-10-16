---
title: task-roadmap — resolve the main tree from a worktree
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

Part of PLUG-062 (epic `crew-worktrees`). task-roadmap takes the project from
`$CLAUDE_PROJECT_DIR`, else `pwd` (`generate.sh`, `regenerate-hook.sh:10`). In a worktree, it
reads that worktree's stale copy of the tasks and writes a roadmap there.

## Scope

- The same rule as the task plugin's resolver, in task-roadmap's own `lib.sh` (plugin
  independence: no shared code). From a worktree, the project is the main tree, i.e. the parent of
  `git rev-parse --path-format=absolute --git-common-dir` when non-bare. Otherwise unchanged.
- Version bump of task-roadmap (plugin.json, marketplace.json).

## Acceptance criteria

- Run from a worktree of a fixture repo, `generate.sh` reads the main tree's tasks and writes the
  main tree's roadmap, and the worktree is unchanged.
- No git, and a bare repo: unchanged from today.
- The new test is seen red before the fix.

## Notes

- Independent of the task plugin's change; can run in parallel with it.
- Tests create worktrees only in temporary fixture repos.

## Current State

Approved (2026-10-16). Nothing changed in code.
