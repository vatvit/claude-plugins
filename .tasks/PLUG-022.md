---
title: task — session-active.sh stores a bare id, which silently empties the active list
status: completed
type: bug
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | lib.sh, resolve-task/epic, session-active, status-session suite read |
| 20 | Requirements | skipped | acceptance criteria already in the task |
| 30 | Assessment | done | canonicalisation inlined in resolve-task.sh, regex repeated in resolve-epic.sh |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | one task_canonical_id in lib.sh, used by all three |
| 70 | Tests | done | 9 cases, red before the fix |
| 80 | Subtasks | skipped | small bug |
| 90 | Implementation | done | 1.4.0 -> 1.4.1 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | task/CLAUDE.md, references/scripts.md |

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

## Context

- Id canonicalisation lived inline in `resolve-task.sh` (number → `PREFIX-NNN`); `resolve-epic.sh` repeated
  the full-id regex; `session-active.sh` stored the raw argument, and its `get` accepted the stored value
  only if the whole list matched, so one bad entry emptied it.
- `set-status.sh` already passes the canonical id; the bare id came from Claude calling
  `session-active.sh add 21 --force` directly (the conflict path in `commands/do.md`).

## Results

- `task_canonical_id <prefix> <raw>` in `lib.sh` is the one place a number becomes a full id
  (`4`, `004`, `PREFIX-4` → `PREFIX-004`; another prefix's full id kept). `resolve-task.sh` and
  `resolve-epic.sh` use it.
- `session-active.sh`: `add`/`set`/`remove` canonicalise the id; an epic-name resolves to its id;
  anything that resolves to no task is rejected (exit 1, list unchanged). On read each entry goes
  through the helper: a stored bare number becomes its full id, a malformed entry is dropped alone,
  and the next write stores the cleaned list.
- `status-session.test.sh` 26 → 35 cases, all 9 new ones red before the fix. All task suites green on
  host, `bash:5` (worktree suite skipped: no git there) and a standalone copy. Live check on this
  session's storage: `add 22` → `status=present active=PLUG-022`.
- task 1.4.0 → 1.4.1 (SKILL.md version was stale at 1.1.0, synced).

## Current State

Implemented, verified, committed and pushed.
