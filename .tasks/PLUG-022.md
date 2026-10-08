---
title: task — session-active.sh stores a bare id, which silently empties the active list
status: proposed
type: bug
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

`session-active.sh <tasksDir> <prefix> add 21` stores `21` as given instead of the canonical
`PLUG-021` (same for `set` / `remove`). The `get` path only accepts a value matching
`^[A-Za-z]+-[0-9]+(,…)*$`, so once a bare id is in the list the **whole list** reads as empty —
every active task is lost, silently. Found during PLUG-020/021 (2026-10-08): `set-status.sh`
returned a conflict and the follow-up `add 21 --force` produced `active=PLUG-016,PLUG-020,21`.

## Acceptance criteria

1. `add`, `set` and `remove` canonicalise the id the way `resolve-task.sh` does (bare number,
   zero-padded number and full id all store `PREFIX-NNN`).
2. A list already holding a malformed entry keeps its well-formed entries on `get`, not none.
3. Cases in `status-session.test.sh`; host + container.
