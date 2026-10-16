---
title: crew — copy new becomes a detached worktree in .worktrees/; .gitignore line; guard allows only crew's own worktree commands
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | copy.sh made a clone; lib.sh ROOT was the session's own tree, so inside a worktree crew saw a different repo |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | crew_try_init must map a linked worktree to the main tree, or copy commands and hooks break inside a copy |
| 40 | POC | skipped | no risky unknown |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | ROOT/CREW_TREE split in the one rev-parse; CREW_WT, crew_wt_dir, crew_wt_ignore in lib.sh; meta in the copy's git dir |
| 70 | Tests | done | copy.test.sh: 72 cases (24 new); red before the fix, 3 red with the mapping and the pre-edit skip put back |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | all 13 crew suites green on host and crew-test |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | crew CLAUDE.md design rules, copy-apply.md, land.md, playbook, SKILL (rule 1, trigger), README |

## Description

Part of PLUG-062 (epic `crew-worktrees`). `copy new` makes a `git clone --shared`
(`crew/scripts/copy.sh:61`). The user decided to use git's built-in feature instead:
`git worktree add --detach`. That is a private checkout at a commit with no branch, which is
what a copy is today.

## Scope

- `copy new <name> [--at COMMIT]` creates `.worktrees/<repo>-<name>` as a detached worktree.
  `copy status`, `copy rebase` and `apply` keep their rules (file by file, merge or refuse, no
  commits, no branch).
- Removing a copy goes through crew, and is refused while it has uncommitted work.
- The first worktree adds `/.worktrees/` to the main tree's `.gitignore`. It does so only when
  `git check-ignore -q .worktrees/` fails; the write is diff-guarded, the file is created if
  absent, and the change is left uncommitted.
- crew recognises its own worktrees by folder and branch and leaves others alone.
- The pre-bash guard: a raw `git worktree` from a member stays denied, and crew's own commands
  work. Update the denial text (`land.sh:85`) and `references/land.md`.
- `references/copy-apply.md` and the skill wording.
- Hooks running inside a worktree (`.git` is a file there): they take the slow path, so prove they
  still find the crew.

## Acceptance criteria

- `copy new` in a fixture repo gives a detached worktree under `.worktrees/`, and `git status` in
  the main tree stays clean apart from the `.gitignore` line.
- An existing ignore rule means `.gitignore` is not touched.
- `copy rebase` and `apply` pass their current tests against a worktree copy.
- A member's raw `git worktree add` is denied; `crew copy new` is not.
- Host bash 3.2 and the `crew-test` image both green.

## Notes

- Needs nothing. PLUG-066 (task worktrees) and PLUG-067 (gitignored files) build on it.
- No crew version bump here: the epic bumps crew once when it closes.
- The folder name `<repo>-<name>` is also the Docker project name (Docker option B).

## Current State

Implemented (2026-10-16), not committed. No crew version bump (the epic bumps once).

## Implementation (2026-10-16)

- `crew_try_init` (lib.sh): one `rev-parse` gives `--show-toplevel --git-common-dir --git-dir`.
  `CREW_TREE` is the session's own tree; `ROOT` is the main tree when the common dir is a
  `<main>/.git`. State stays in the common dir. A command run inside a copy acts on the crew.
- `copy new <name>`: `valid_name`, then `git worktree add --detach` into
  `.worktrees/<repo>-<name>`; meta `crew-copy` in the copy's own git dir, so a pre-2.1 clone
  copy still works by path. `status`, `rebase`, `apply` take a name or a folder (`copy_dir`).
- `crew_wt_ignore`: appends `/.worktrees/` to `.gitignore` only when `git check-ignore` fails;
  diff-guarded, creates the file if absent, left uncommitted.
- `copy remove <name>`: only a registered worktree that `copy_check` accepts; refused while any
  changed path differs from the tree; then `git worktree remove --force`. A folder in
  `.worktrees/` that is not crew's copy is refused and left alone.
- pre-edit hook: `.worktrees/*` is skipped (no hold, snapshot or claim). The pre-bash guard
  still denies a raw `git worktree`; the denial names `copy new` / `copy remove`.
- Fixed in the test along the way: a hold is released with `--unchanged` (a bare `release` is refused).
