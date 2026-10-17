---
title: crew — `crew end`: disband a crew and return the repo to the no-crew state
status: proposed
type: feature
epic: crew-solo
priority: medium
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

## Current State

Proposed 2026-10-17 (epic PLUG-073). Not started.
