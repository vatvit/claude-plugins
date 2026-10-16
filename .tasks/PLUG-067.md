---
title: crew — gitignored files in a new worktree — link the listed local files, print the regenerate step
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

## Current State

Approved (2026-10-16). Nothing changed in code.
