---
title: crew — gitignored files in a new worktree — link the listed local files, print the regenerate step
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | a worktree holds tracked files only; copy new and tree new both end in crew_wt_add |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | links must not count as work, or every sync, remove and apply would refuse; a tracked path must never be replaced |
| 40 | POC | skipped | no risky unknown |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | crew_wt_ready (lib.sh) is the one post-creation step: links, setup print, compose report; crew_link_filter drops links from dirty and changes |
| 70 | Tests | done | link.test.sh: 23 cases, red before (12 failing); each defect put back went red (runtime path check 2, config path check 4, path rule 6, links dirty 3, links as changes 1, setup not printed 1, tracked file replaced 4, remove without force 1) |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | all crew suites green on host, crew-test and a standalone copy |
| 100 | Tech Debt | done | copy and tree share crew_wt_ready and crew_wt_dirty; no second copy of the post-creation step |
| 110 | Reflection | done | trees.md section, copy-apply.md, config.md rows, SKILL pointer row, README, crew CLAUDE.md |

## Description

Part of PLUG-062 (epic `crew-worktrees`). A new worktree has no untracked files: no `.env`, no
local config, no dependencies, no build output. The user agreed: local settings and secrets are
linked, and whatever is built from the branch's code is regenerated.

## Scope

- A project config key with the list of paths to link (e.g. `.env`, local config). crew treats
  each entry as data: a path relative to the main tree that must stay inside it, is never
  executed, and is skipped with a note when it is absent.
- When crew creates a worktree, it links each listed path from the main tree into it.
- "Regenerate" (dependencies, build output, migrations and seed data for an empty database) is the
  project's own install step. crew prints it from config for the session to run, and never runs a
  configured command itself.

## Acceptance criteria

- The listed files are links in a new fixture worktree; an absent one gets a note, and a path that
  points outside the main tree is refused.
- With no key, nothing is linked and nothing breaks.
- The regenerate step is printed, not executed.

## Notes

- Needs PLUG-065 for the call site where a worktree is created.

## Implementation (2026-10-16)

- Config: `treeLink` (array of paths) and `treeSetup` (string), both project-only. `config set`
  refuses a `treeLink` path that is absolute or uses `..` (`crew_link_ok`).
- lib.sh `crew_wt_ready <dir>`, run after every `crew_wt_add` (copy new, tree new): links each
  `treeLink` path from the main tree with `ln -s`; skips with a note a path outside the tree
  (hand-edited config is checked again), one absent from the main tree, and one tracked in the
  worktree; prints `treeSetup` ("crew prints it, never runs it"); then the compose report.
- `crew_link_filter` / `crew_wt_dirty`: links never count as uncommitted (status, tree sync,
  tree remove) or as a copy's changes (copy status, apply). `tree remove` uses
  `worktree remove --force` after crew's own clean check, since git counts the links as untracked.
- Scope note: "regenerate" is the printed `treeSetup` step; nothing configured is ever executed.

## Current State

Completed (2026-10-16). All crew suites green on host, crew-test and a standalone copy. Not
committed. Next: close epic PLUG-062.
