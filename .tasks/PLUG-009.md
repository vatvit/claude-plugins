---
title: Task list and status rendering move from prose into scripts
status: proposed
type: refactor
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

Large parts of the task skill's `SKILL.md` are not instructions — they are programs written in
English, executed by the model by hand on every invocation. `### LIST` is 223 lines of
filtering, `,_` appending, grouping, priority sorting, ">5 rows" collapsing, epic-name → task-ID
resolution per row and column rendering. `### DO` is another 146. The session-storage
`active-tasks` rules are 53 more lines of pure list manipulation.

Move that work into bash + awk, where it belongs, and leave the prose to say only what requires
judgement.

## Why

Two wins, and the second matters more than the token count:

- **Reproducibility.** Hand-executed rendering gives a slightly different table each time —
  different collapse thresholds, forgotten columns, a mis-sorted priority. A script gives the
  same answer every run and can be tested.
- **Tokens.** ~300 of the 1039 lines stop being resident on every `/task` invocation.

It also removes a standing DRY violation: `read-tasks.sh`'s options are documented twice
(the LIST procedure and the Scripts reference), the epic-detection rule appears in three
places, and the closed-sub-task collapse rule is now stated in both the list section and the
epic dashboard. The script's own `--help` becomes the single source.

## Depends on

**PLUG-008** — the plugin move. Do not start this before the move has landed; both edit the
same `SKILL.md` and doing them in the other order means porting code that is about to be
deleted.

## Scope

- `list-tasks.sh <tasksDir> <prefix> [filters…]` — filters (`=`, `~`, `,` OR, `_` unset), the
  `epic=` smart `,_` default, bare-ID epic resolution, grouping, sorting, group collapsing,
  the closed-sub-tasks collapse in epic views, the Epic column with its ID cache, and omitting
  columns no task populates. Prints the finished table.
- `set-status.sh <tasksDir> <prefix> <id> <status>` — frontmatter write, parent-epic cascade to
  `in-progress`, and the session-storage add/remove in one call.
- `session-active.sh <get|add|remove> <id>` — the `active-tasks` rules including the
  parent-epic append-silently case; a no-op exit 0 when session-storage is absent.
- Rewrite the corresponding `SKILL.md` sections down to: which script to call, how to present
  the output, and the genuine judgement calls that remain (the append/switch/cancel prompt,
  when to ask before skipping a workflow step).
- Tests under `scripts/test/` alongside the existing `epic-dashboard.test.sh`, in the same
  style — plain bash, no dependencies, runnable in an isolated copy of the plugin.

## Out of scope

- Any change to the rendered output. The tables the scripts print must match what the current
  prose specifies, collapse lines and all. This is a change of executor, not of behaviour.
- The SKILL.md router split — that is the sibling task, done after this one.

## Acceptance criteria

- `/task list`, `/task list <epic-id>`, `/task list epic=x group=y sort=z`, `summary` and `all`
  all produce their documented output via one script call each.
- Output verified against this repo's `.tasks/` (`PLUG-*`, epic `diagram-support`) and against
  a larger set — `project-a` (`PA`) has enough tasks to exercise grouping and
  collapsing.
- The guardrails stay in prose, not in a script: never invent an ID, never change status
  without approval.
- `SKILL.md` is at least 250 lines shorter with no capability lost.
- Tests pass in an isolated copy of the plugin directory.
