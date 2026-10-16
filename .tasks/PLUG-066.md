---
title: crew — worktree mode — the tree key asked once per project, the user's per-task exception, a task worktree on task/<ID>, merge into the coordinator's branch
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

Part of PLUG-062 (epic `crew-worktrees`). It holds the model the user agreed there: one task, one
branch, one worktree, one session; members merge locally and only the coordinator pushes.

## Scope

- Config key `tree`: `shared` | `worktrees`, project layer only (never the user layer). While
  undecided, `shared` holds; `git_policy_note` (lib.sh) reports it; the coordinator asks once and
  records only the user's answer.
- Under `shared`, the user's per-task exception: the coordinator records it, `status` shows it,
  and it ends when the task is merged or is revoked.
- `tree new <task-id>`: create the branch `task/<ID>` from the coordinator's branch first, then the
  worktree `.worktrees/<repo>-<id>` on it (PLUG-065's creation code, not a second copy).
- Bring in the destination (merge or rebase, from a config key; merge by default), resolve
  conflicts in the worktree, test there, hand off "branch, sha, tests green". The coordinator
  merges. Then the worktree is removed (refused while dirty) and the branch deleted.
- A member commits on its own task branch. The user may grant a named member a push of its own
  task branch. Pushing the coordinator's branch stays under `push`.
- Guards in a worktree: deny `stash`, moving the coordinator's branch, and any branch but the
  task's own.
- The coordinator regenerates generated files after the merge.
- SKILL.md non-negotiable 1, playbook §1 and the trigger phrases.

## Acceptance criteria

- Undecided `tree` shows the note in `status` and in the coordinator's SessionStart line.
- `tree new` refuses under `shared` without an exception, and works with one.
- The full flow in a fixture repo: branch, worktree, commit, bring in the destination with a
  conflict, resolve, merge, clean up.
- Each guard is denied in a worktree and seen red before it is added.

## Notes

- Needs PLUG-065 (worktree creation and guard changes in the same files).

## Current State

Approved (2026-10-16). Nothing changed in code.
