---
title: task-roadmap — resolve the main tree from a worktree
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | generate.sh and regenerate-hook.sh each resolve ROOT; both source lib.sh |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | ROOT must be set after lib.sh is sourced |
| 40 | POC | skipped | same mechanism as PLUG-063 |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | project_root in task-roadmap/scripts/lib.sh, own copy (plugin independence) |
| 70 | Tests | done | roadmap.test.sh 9c-9h; 5 red before the fix and 5 red with the defect put back |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | 30/30 on host, container and a standalone copy |
| 100 | Tech Debt | skipped | none |
| 110 | Reflection | done | task-roadmap CLAUDE.md (lib.sh section), README usage |

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

Implemented (2026-10-16), not committed. task-roadmap 1.0.3 -> 1.1.0.

## Implementation (2026-10-16)

- `project_root <dir>` in `task-roadmap/scripts/lib.sh`: the same rule as the task plugin's
  `task_project_dir`, in task-roadmap's own copy.
- `generate.sh` and `regenerate-hook.sh` set `ROOT` through it, after sourcing `lib.sh`. A
  hook firing in a worktree session regenerates the main tree's roadmap.
- Tests: `roadmap.test.sh` 9c–9h, run against a fixture repo with a detached worktree and a bare
  repo's worktree.
