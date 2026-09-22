---
title: SKILL.md becomes a router, command detail loads on demand
status: completed
type: refactor
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | Split done on the PLUG-009 output, in the same session — see PLUG-009 ## Context |
| 20 | Requirements | skipped | Scope and acceptance criteria here are the spec |
| 30 | Assessment | done | 1036 lines, 9 rules living in two or three places each. See ## Assessment |
| 40 | POC | skipped | Nothing unknown — a re-layout of prose |
| 50 | Domain | skipped | No new terms |
| 60 | Architecture | done | Router + commands/ + references/; one home per rule. See ## Architecture |
| 70 | Tests | skipped | No code changed; verified by walking all seven commands end to end. See ## Verification |
| 80 | Subtasks | skipped | One slice, done alongside PLUG-009 |
| 90 | Implementation | done | SKILL.md 1036 -> 110; 7 command files, 6 reference files. See ## Implementation |
| 100 | Tech Debt | done | No tickets. One legacy form kept readable but no longer produced |
| 110 | Reflection | done | task/CLAUDE.md Layout + Known shape rewritten for the router |

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

## Assessment

Done against the post-PLUG-009 file, in the same session, which is the order the task
required — splitting first would have meant splitting the ~420 lines PLUG-009 deletes.

Rules found in more than one place, each now with exactly one home:

| Rule | Was in | Now |
|------|--------|-----|
| epic detection (`type: epic`, `EPIC:` title) | LIST, Epic Tasks, epic-dashboard notes | `references/epics.md` |
| closed sub-tasks collapse | LIST, Epic Dashboard | `list-tasks.sh` + its test |
| `read-tasks.sh` flags | LIST procedure, Scripts | the script's `--help` |
| step file resolution order | Workflow System, workflow-guide.md | `references/workflow-system.md` |
| workflow table statuses | Task File Format, Workflow System | `references/task-format.md` |

## Architecture

- `SKILL.md` keeps only what is true whatever command is running: the command table, the
  four guardrails, the `resolve-config.sh` first step, the session-storage detection (it is
  cross-command), the dispatch table and the reference index.
- `commands/<name>.md` — one per command, self-sufficient for that command. Where it needs a
  shared rule it names the file to read; there is no "see the section above" pointing into
  something unloaded.
- `references/` holds what is looked up rather than followed: `task-format.md`, `epics.md`,
  `workflow-system.md`, `configuration.md`, `scripts.md`, plus the existing
  `workflow-guide.md`, trimmed to the authoring side once `workflow-system.md` owned the
  resolution order.

## Implementation

`SKILL.md` 1036 → 110 lines. A command now costs 110 plus one file: 12 (`workflow`) to
126 (`do`, which carries the epic dashboard and the kickoff flow). Reference material is
read only when a command file names it.

Nothing became unreachable. The one rule deliberately not carried forward as guidance is the
legacy `## Workflow Progress` checklist: `references/task-format.md` says to read it where it
exists and not to write it, because the workflow table is the state and two records of the
same thing drift.

## Verification

All seven commands walked end to end against this repo's `.tasks/` (PLUG-001..012, epic
`diagram-support`), following the router to the command file and out to the scripts:
`create` via `allocate-id.sh` in the isolated copy (`port.test.sh`), `list` in every
documented shape, `show` with its epic context line, `do` on the epic dashboard, `finish`
selecting from in-progress tasks, `status` through `set-status.sh`, `workflow` off the
project's `WORKFLOW.md`. Nothing had to be guessed at.

## Current State

Done, shipped with PLUG-009 in one change (`task` 1.0.0 → 1.1.0). 97 tests green on host and
in `bash:5`. Next edit to a `/task list` rule is a script edit, not a prose edit — the
command files say which script owns what.
