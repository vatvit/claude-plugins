---
title: SKILL.md becomes a router, command detail loads on demand
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

The task skill loads its entire `SKILL.md` on every invocation, for every command. A
`/task list` pays for the `do`, `finish`, `create`, epic-format, directory-layout and
script-reference sections it will never read. Split it: `SKILL.md` keeps only what is true
regardless of which command is running, and each command's detail is read on demand.

## Why

~13k tokens resident on every invocation, of which any single command needs maybe an eighth.
The cost is paid in every session that so much as mentions a task ID, because the skill is
model-invocable (`disable-model-invocation: false`).

Progressive disclosure is also the structure the material already wants — `## Commands Detail`
is 480 lines that only ever get consulted one `###` at a time.

## Depends on

**PLUG-008** (the plugin move) and **PLUG-009** (script extraction). Run after both: PLUG-009
deletes ~300 lines from the very sections this task would otherwise split and then re-split.
Doing them in the other order is wasted work and a guaranteed merge conflict — they edit the
same file.

## Scope

- `SKILL.md` keeps: frontmatter, the command table, the hard guardrails (never invent an ID,
  never change status unasked), the config-resolution first step, and a dispatch line — read
  `commands/<name>.md` for the command being run.
- `commands/{create,list,show,do,finish,status,workflow}.md` — one file per command.
- `references/` takes the material that is looked up rather than followed: task file format,
  artifacts folder, directory layout, reserved fields, epic task format, the workflow system,
  and the script reference.
- Fold the duplication found while splitting rather than copying it into two files — the epic
  detection rule, the closed-sub-task collapse rule and the `read-tasks.sh` flag list each
  get exactly one home, referenced from elsewhere.

## Out of scope

- Behaviour changes of any kind. This is a re-layout; every rule that exists today must still
  be reachable, from a file the dispatch line names.
- Touching the scripts.

## Acceptance criteria

- Resident `SKILL.md` under ~150 lines; every command still fully specified somewhere.
- Each command's file is self-sufficient for that command — no "see the section above" that
  points into a file the model has not loaded.
- Walk all seven commands end to end against this repo's `.tasks/` and confirm nothing has to
  be guessed at; a rule that cannot be found from the dispatch line is a failed split.
- No rule text exists in two files.
