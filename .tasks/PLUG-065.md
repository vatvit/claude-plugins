---
title: crew — copy new becomes a detached worktree in .worktrees/; .gitignore line; guard allows only crew's own worktree commands
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

Approved (2026-10-16). Nothing changed in code.
