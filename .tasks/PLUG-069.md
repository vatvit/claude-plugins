---
title: crew — status lists the worktrees — task, branch, owner, unmerged commits, lag, uncommitted files
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | status.sh sources status.d/*.sh; a part must end true under set -e |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | the owner was not recorded anywhere: copy meta gains by= (kept on rebase); PLUG-066 records task worktrees the same way |
| 40 | POC | skipped | no risky unknown |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | status.d/trees.sh parses worktree list --porcelain in awk into TSV; reuses copy.sh copy_meta/copy_metafile via load_area |
| 70 | Tests | done | trees.test.sh, 12 cases; red before (9 failed), 3 red with the main-tree skip and the rebase owner broken |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | all 15 crew suites green on host, crew-test and a standalone copy |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | status help line, README, SKILL status sentence |

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

Implemented (2026-10-16), not committed. No crew version bump (the epic bumps once).

## Implementation (2026-10-16)

- `crew/scripts/status.d/trees.sh`: `trees: N crew worktrees · M not crew's (left alone)`, then one
  line each: `.worktrees/<repo>-<x> · task <ID>|copy <name> · <branch>|detached · by <name|?> ·
  N unmerged · N behind · N uncommitted`, counted against `shared_branch`. Crew's own: under
  `.worktrees/<repo>-` and either on `task/<ID>` or detached with a `crew-copy` record. Silent
  when the repo has no linked worktrees; foreign-only prints the one count line.
- `copy_write_meta` records `by=` (the caller's crew name, empty when unknown); `copy rebase` keeps it.
- `copy_meta` now ends in `|| true`: under `pipefail` a missing record aborted the status part.
- copy.test.sh's "not claimed" check read all of `status`, which now names `.worktrees`, and
  could never fail anyway (the folder is ignored, so never dirty). It reads the claims file now,
  and was seen red with the pre-edit skip removed.
