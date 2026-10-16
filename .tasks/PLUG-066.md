---
title: crew — worktree mode — the tree key asked once per project, the user's per-task exception, a task worktree on task/<ID>, merge into the coordinator's branch
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | copy was the only worktree; the guard and land assumed one tree and one branch |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | the guard is keyed on the session name; it must also know which tree the git command runs in |
| 40 | POC | skipped | no risky unknown |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | tree.sh (dual-use); crew_wt_add and the record helpers moved to lib.sh; task= in the record marks a task worktree for the guard |
| 70 | Tests | done | tree.test.sh: 70 cases, red before (46 failing); each defect put back went red (guard block 13, stash 3, push refspec 1, taskPush 1, -C 1, exception 3, human-approved 4, note 2, copy refusal 1) |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | all 16 crew suites green on host, crew-test and a standalone copy |
| 100 | Tech Debt | done | copy meta helpers unified into lib.sh (crew_wt_*), one creation path crew_wt_add |
| 110 | Reflection | done | references/trees.md (new), SKILL rule 1 + coordinator + triggers, playbook §1, config.md, README, crew CLAUDE.md |

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

## Implementation (2026-10-16)

- Config: `tree` (shared|worktrees, default shared), `treeSync` (merge|rebase, default merge),
  `taskPush` (crew names), all project-only. `tree_policy_note` (lib.sh) reports `tree` unset in
  the project layer; `status` prints it as `worktrees: …`, the coordinator's SessionStart line too.
- `crew tree new|sync|merge|remove <ID>`, `tree allow|revoke <ID>` (coordinator; `$STATE/tree-allow`).
  `new` is refused under `shared` without an exception; it branches `task/<ID>` from the shared
  branch, then `crew_wt_add`. `sync` refuses a dirty or mid-merge tree and names conflicted files.
  `merge` (coordinator, under the apply lock) does `--no-ff`, aborts and changes nothing on a
  conflict, then removes worktree, branch and exception and prints the regenerate step; under
  `committer=human-approved` it prints the merge instead. `remove` is refused while dirty or unmerged.
- lib.sh: `crew_wt_add` (the one creation path, used by copy new and tree new), `crew_wt_metafile`,
  `crew_wt_meta`, `crew_wt_write_meta` (with `task=`), `crew_wt_task`. copy.sh uses them, and
  `copy_check` refuses a task worktree.
- Guard (land.sh): the tree is the session's own or `git -C`'s; in a task worktree it denies stash,
  raw worktree, branch make/move/delete, checkout/switch off `task/<ID>`, update-ref/symbolic-ref,
  fetch into a branch, and a push unless the member is in `taskPush` and names only its own branch.
  The pre-bash filter now also passes update-ref, symbolic-ref and fetch.
- status: `worktrees: tree=… · the user's exceptions: …` when there are any.
- land.test.sh: "decided in the user layer" now looks for the commits-and-pushes note only.

## Current State

Completed (2026-10-16). All crew suites green on host, crew-test and a standalone copy. Not
committed. Next: PLUG-067.
