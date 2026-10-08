---
title: crew — snapshot before every write, log/show/restore
status: proposed
type: feature
epic: crew
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

A snapshot before every write, so an overwritten edit can always be recovered (playbook §3).

- A PreToolUse hook on Write/Edit/MultiEdit/NotebookEdit copies the target's current content
  (when the file exists and differs from the last snapshot) to `.git/crew/snapshots/`,
  recording session, time and path. The hook never blocks and stays fast.
- `snapshot.sh log <path>`, `show <id>`, `restore <id>` (restore is itself snapshotted
  first), `prune` (by `snapshotKeep` count/age in `.crew.json`).
- Size guard: files above a set limit and binary files are skipped with a single stderr note.
- `references/snapshots.md`.

## Acceptance criteria

- [ ] s1 edits a file and s2 overwrites it. `log` shows both versions and `restore` brings
      s1's version back.
- [ ] An unchanged file is not snapshotted twice in a row.
- [ ] `prune` respects the retention setting.
- [ ] The hook adds under ~50 ms on a normal source file and never fails the tool call.
- [ ] The suite passes in docker and from a standalone copy.
