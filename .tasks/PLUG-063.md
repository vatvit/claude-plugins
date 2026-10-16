---
title: task — the resolver finds the main tree from a worktree; the skill uses only the paths the scripts print
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

Part of PLUG-062 (epic `crew-worktrees`). The task scripts take the project from `pwd`
(`task/scripts/resolve-config.sh:18`). In a worktree, that finds the worktree's own copy of
`.task-config.json` and `.tasks/`. So the id lock (`allocate-id.sh:55`) and the id sequence are
per worktree, and two worktrees can create the same id. That is true today for any worktree,
including Claude Code's own `.claude/worktrees/`.

## Scope

- `resolve-config.sh`: the project is the main tree, i.e. the parent of
  `git rev-parse --path-format=absolute --git-common-dir` when that is a non-bare repo.
  Otherwise `pwd`, as today, which also covers no git and bare repos. An explicit argument still wins.
- Every script that resolves the project goes through it (check `allocate-id.sh`, `set-status.sh`
  and the rest).
- The skill extends the guardrail "only the path `allocate-id.sh` printed" to every command:
  task files are read and edited only by the absolute path the scripts print, never by a path
  relative to the working directory. That keeps the worktree's stale tracked copy untouched.
- Version bump of the task plugin (plugin.json, marketplace.json).

## Acceptance criteria

- In a fixture repo with a worktree, `resolve-config.sh` run inside the worktree prints the main
  tree's `tasksDir`.
- Two `allocate-id.sh` calls, one from the main tree and one from the worktree, get different ids
  from one sequence.
- Outside git, and in a bare repo, the result is unchanged from today.
- The new tests are seen red before the fix.

## Notes

- Tests create real worktrees only in temporary fixture repos (allowed by the user, 2026-10-16).
- Plugin independence: no crew code, no crew assumption.

## Current State

Approved (2026-10-16). Nothing changed in code.
