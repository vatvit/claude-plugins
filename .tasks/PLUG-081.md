---
title: task — one shared test helper file for the suites' check/contains/lacks
status: completed
type: refactor
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | 7 identical check(), 2 contains/lacks, same TMP/trap/counters |
| 20 | Requirements | skipped | the acceptance criteria are the spec |
| 30 | Assessment | done | no suite has its own trap; nothing parses the summary lines |
| 40 | POC | skipped | mechanical |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | test/lib.sh: ROOT, SC, TMP+trap, counters, check/contains/lacks, report <suite> |
| 70 | Tests | done | counts unchanged per suite; a mutated parser still exits 1 |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | below |
| 100 | Tech Debt | done | none left |
| 110 | Reflection | done | task/CLAUDE.md: new suites source lib.sh |

## Description

Every suite in `task/scripts/test/` defines its own `check` / `contains` / `lacks` (and
pass/fail counters, TMP + trap). PLUG-080 added `tags.test.sh` with the seventh copy rather
than starting a second way mid-task. Move them into one `scripts/test/lib.sh` sourced by
every suite, inside the task plugin (DRY within a plugin; never across plugins).

## Acceptance criteria

- One definition of each helper in `task/scripts/test/`; every suite sources it.
- Each suite's pass/fail counts are unchanged, host and `bash:5` container.
- `port.test.sh` still passes from a standalone copy of `task/`.

## Implementation

`task/scripts/test/lib.sh` (new) holds what every suite repeated; the seven suites source it and
end with `report <suite>`, so every closing line now reads `<suite>: N passed, M failed`.
Before/after per suite: config 13, epic-dashboard 21, list-tasks 41, port 19, status-session 26,
tags 48, worktree 14 — identical, host and `bash:5` (worktree run in Alpine with git).

## Current State

Completed 2026-10-23. Not committed. Ships in the same unreleased task 1.4.0 as PLUG-080.

