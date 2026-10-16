---
title: task — the resolver finds the main tree from a worktree; the skill uses only the paths the scripts print
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | only resolve-config.sh and allocate-id.sh take a project dir; the rest take tasksDir |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | lib.sh is the home for a shared helper; allocate-id also keys the global registry by project dir |
| 40 | POC | skipped | no risky unknown |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | task_project_dir in lib.sh; cd + pwd -P instead of --path-format (needs git 2.31) |
| 70 | Tests | done | worktree.test.sh, 14 cases; seen red (10 failed) before the fix, 7 red with the defect put back |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | all 6 suites green on host, container and a standalone copy |
| 100 | Tech Debt | done | none filed; see the known limit below |
| 110 | Reflection | done | task CLAUDE.md (do-not-regress + test list), README, SKILL, references |

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

Implemented (2026-10-16), not committed. task plugin 1.1.2 -> 1.2.0.

## Implementation (2026-10-16)

- `task_project_dir <dir>` in `task/scripts/lib.sh`: in a linked worktree (git-dir differs from
  the common dir, and the common dir is a `.git` folder) it returns the main tree plus the same
  subdirectory. Everywhere else it returns `<dir>` as given.
- `resolve-config.sh` and `allocate-id.sh` both pass their project dir through it. The allocator's
  global-registry `nextId` write uses the mapped dir too. These are the only two scripts that take
  a project dir; the rest take `tasksDir`.
- `resolve-config.sh` also prints `projectDir=`.
- The skill tells the reader to touch task files only at the absolute paths the scripts print. The
  reasoning lives in `references/configuration.md`.
- Tests: `task/scripts/test/worktree.test.sh` (14 cases). Seen red before the fix, and red again
  in a copy with the helper reduced to identity.
- Known limit: a project registered in the *global* registry under a path that goes through a
  symlink resolves from a worktree to the canonical path (`pwd -P`), so the lookup can miss.
  Project-local `.task-config.json` is unaffected. Not filed: no such setup is known.
