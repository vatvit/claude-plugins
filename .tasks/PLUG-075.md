---
title: crew — `crew end`: disband a crew and return the repo to the no-crew state
status: completed
type: feature
epic: crew-solo
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | below |
| 30 | Assessment | done | crew_trees refactor needed for DRY |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | end.sh; never deletes worktrees |
| 70 | Tests | done | end.test.sh, seen red |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | crew/CLAUDE.md |

## Description

A crew can start but not end. `whoami --leave` takes one session out; nothing closes the crew. Today it
"ends" by its sessions closing, leaving holds, queued slots, registry names and `<git-common-dir>/crew/`
behind, so the repo never goes back to the silent no-crew state.

## Requirements (negotiable)

- `crew end` (coordinator only, or with an explicit confirm): release every hold, cancel every slot,
  free the crew's names in the machine registry, send each member a final message, and remove the crew
  state so every hook exits early again ("no crew, no cost").
- Refuses, with the list, when something would be lost: unlanded work in a copy or task worktree,
  unread mail. A `--force` (or the user's explicit word) overrides; decide at Requirements.
- Keeps a short record of the end (who, when, what was released) outside the removed state, or in the
  commit/inbox history — decide at Architecture.
- Idempotent: `crew end` on a repo with no crew prints that and exits 0.

## Acceptance criteria

- Fixture crew with two members, a hold, a queued slot, registered names: after `crew end`, no hold, no
  slot, names free in the registry, members got the message, and the SessionStart hook prints nothing
  for that repo.
- With an unlanded copy: refused, and the copy named.
- Second run: no-op, exit 0.
- Suite green on host and `bash:5`, and from a copy of `crew/` alone.

## Notes

- Files: `crew/scripts/crew.sh` (dispatch), a new script or `whoami.sh`, `holds.sh`, `slot.sh`,
  `scripts/test/`, SKILL.md trigger phrases (*end the crew*, *disband*, *close the crew*), README.

## Outcome (2026-10-17, crew 2.2.0)

- `crew end [--force]` (`scripts/end.sh`): coordinator only; refuses (listing each) while a crew copy
  has `copy_unlanded` paths, a task worktree has unmerged or uncommitted work, or a member has unread
  mail. `--force` (the user's word) works from any session, also with nobody left.
- Ending: this crew's slots dropped (`slots_drop`), every name `reg_drop`ped, one line appended to
  `$CREW_HOME/ended`, `$STATE` and `crew-pending` removed. Prints what was released, the worktrees left
  in place (never deleted), and a ready CREW ENDED message plus the members to send it to (the
  mailbox goes with the state). A second `end` is a no-op, exit 0.
- `whoami --leave` now also drops the leaver's slots.
- DRY: the worktree listing moved from `status.d/trees.sh` into `tree.sh` as `crew_trees`; status and
  end both read it (trees.test.sh unchanged and green).
- Tests `end.test.sh` (18). Seen red before the code (16 failing) and with the lost-work check
  disabled (7 failing).

## Current State

Completed. Host, `bash:5` container and a sibling-free copy of `crew/`: ALL GREEN.
