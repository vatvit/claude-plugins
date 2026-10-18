---
title: task — /task do and /task finish work a whole epic by name or id; membership from the `epic:` field alone
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | in the task |
| 30 | Assessment | done |  |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | one sort replaces four trackers; resolve-task takes a name |
| 70 | Tests | done | epic-dashboard.test.sh T1-T13, seen red |
| 80 | Subtasks | skipped | one task, shared files |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | READMEs, CLAUDE.md, memory |

## Description

Two changes to how the task plugin handles epics.

1. **Membership has two sources, kept in step by hand.** A sub-task is one whose frontmatter says
   `epic: <epic-name>` *and* whose id is an entry in the epic's `## Sub-tasks` list. That is the same
   fact stored twice, which breaks DRY: `create.md` tells you to update both, `epic-dashboard.sh` reads only the list,
   and `list-tasks.sh` reads only the field. So the two views of one epic can disagree. The `epic:` field becomes
   the single source; the epic's description never lists its sub-tasks.
2. **`/task do <epic>` and `/task finish <epic>` don't work the epic.** Today both show the dashboard and ask
   for one sub-task, and `finish` refuses an epic outright. Both only accept an id. They should take an
   epic **name or id** and work the epic itself plus all its sub-tasks.

One task, not an epic of two: both halves edit `epic-dashboard.sh`, `do.md`, `finish.md` and
`epics.md`, so two slices would collide in the same files, and part 2's sub-task ordering depends on part 1's membership.

## Decisions (agreed with the user, 2026-10-18)

- **`/task do <epic>`**: work the open sub-tasks one after another, with `do`'s usual pause before each step.
  When a sub-task is completed, go straight on to the next. Order: in-progress → approved → proposed, then
  priority, then id (the dashboard's existing recommendation order). Blocked sub-tasks are skipped and
  reported.
- **The epic's own workflow table wraps the sub-tasks.** First the epic's steps before `implementation`
  (planning; its `subtasks` step is today's Kickoff when the epic has no sub-tasks), then the sub-tasks,
  then the epic's remaining steps (tech-debt, reflection).
- **`/task finish <epic>`**: one confirmation that lists every open sub-task, proposed ones included, then
  run them like `finish` does. Blocked ones are skipped and reported. The epic goes `completed` only once
  every sub-task is completed or rejected; otherwise it stays `in-progress` and the reason is given.
- **Existing `## Sub-tasks` sections stay as history.** Tasks are append-only after implementation. The
  parser stops reading the section, so what is there becomes harmless prose. New epics and Kickoff never write one.

## Requirements (negotiable)

- `epic-dashboard.sh` derives sub-tasks from `epic: <epic-name>` across the task set, via `read-tasks.sh`
  (the one parser), not from the `## Sub-tasks` section.
- `do` / `finish` resolve their argument as an id or an epic-name. A plain task id behaves as today. A name
  that matches no epic, or an id that is not an epic, gives a clear error.
- `create.md` "Creating a sub-task" just sets `epic:`. `epics.md` example and membership rules
  are rewritten. The `CLAUDE.md` "Epic membership is list items and table rows only" rule is replaced by
  "membership is the `epic:` field".
- An epic file whose `## Sub-tasks` section lists an id with no matching `epic:` field doesn't
  count that task (regression test: the list no longer counts).

## Acceptance criteria

- Fixture: epic with three children via `epic:` field and no `## Sub-tasks` section → the dashboard lists all three.
- Fixture: an epic whose `## Sub-tasks` lists a task that lacks the `epic:` field → that task is not a member.
- `do`/`finish` given an epic-name and given an epic id resolve to the same epic, and a non-epic name is refused.
- The sub-task order is in-progress → approved → proposed → priority → id, and blocked ones are reported, not picked.
- Each new test is seen red against the old behaviour.
- Suites green on host and `bash:5`, and from a copy of `task/` alone.
- Version bump 1.2.0 → 1.3.0: `plugin.json`, `marketplace.json`, SKILL.md trigger phrases/command help.

## Notes

- Files: `task/scripts/epic-dashboard.sh` (+ maybe `resolve-epic.sh`), `scripts/test/epic-dashboard.test.sh`,
  `port.test.sh` (mentions Sub-tasks), `skills/task/commands/{do,finish,create}.md`,
  `references/{epics,scripts}.md`, `SKILL.md`, `task/CLAUDE.md`.
- `task-roadmap` doesn't read `## Sub-tasks` (checked), so it isn't affected.

## Context

- `resolve-epic.sh` already resolves an id, a bare number or an epic-name (index, then scan), so
  "accept a name or an id" doesn't need a new resolver. `do`/`finish` just have to call it.
- `list-tasks.sh <epic>` already groups by the `epic:` field. Only `epic-dashboard.sh` reads `## Sub-tasks`,
  and it calls `resolve-task.sh` once per listed id. After the change it reads every task in one
  `read-tasks.sh --all --records` pass and joins on `epic`.
- The dashboard's recommendation already ranks in-progress → blocked → approved → proposed, then priority,
  then id, using four hand-kept "best" trackers. The work queue needs the same ranking without blocked.
- The existing tests (`epic-dashboard.test.sh` T1–T11) all test list parsing, which is the thing going away.
  `port.test.sh` T8 only puts a `## Sub-tasks` section in an allocate fixture, so it isn't affected.
- `task-roadmap` and the root README don't read `## Sub-tasks` either.

## Assessment

Ready. Nothing else depends on the dashboard's JSON beyond `do.md`/`finish.md`. Adding a field is backward
compatible.

## Architecture

- `epic-dashboard.sh`: members are tasks with `epic == <epic-name>` (never the epic itself). awk emits one
  TSV row per member, `rank<TAB>prio<TAB>num<TAB>id<TAB>title<TAB>status<TAB>priority`, and a single `sort`
  gives the work order. That replaces the four trackers. New JSON field `"queue":[ids]`: open,
  non-blocked members in work order. `recommend` = head of the queue, else the best blocked
  member (reason `blocked`), else `all-done`. That's the same contract as today.
- Accept an epic-name as the argument via `resolve-epic.sh`, so the script and the commands resolve the
  same way.
- `do.md` Epic flow: planning steps of the epic → the queue, one sub-task at a time as `/task do`
  → the epic's remaining steps. `finish.md`: confirm once, then the queue as `finish`, then the epic's
  remaining steps, and `completed` only if `recommend_reason=all-done`.

## Outcome (2026-10-18, task 1.3.0)

- `epic-dashboard.sh` reads members from the `epic:` field in one `read-tasks.sh` pass. awk ranks each
  member and one `sort` gives the work order, replacing the four "best" trackers. New `queue` field, plus
  `epic-name` in the JSON. A title is escaped in awk with a character loop: `gsub` with a backslash
  replacement failed T12 under busybox (seen red in `bash:5`), which is the root CLAUDE.md trap.
- `resolve-task.sh` takes an epic-name and hands it to `resolve-epic.sh`, so every command that resolves an id
  (`do`, `finish`, `show`, `status`) takes a name too, from one rule.
- `do.md` Epic flow: planning rows → queue (each sub-task as `/task do`, epic "Current State" updated
  between them) → closing rows. `finish.md` has a new "Finishing an epic" section. Kickoff no longer lists ids
  in the epic. `create.md`, `epics.md`, `scripts.md`, `SKILL.md`, `task/CLAUDE.md` and both READMEs are
  updated. The version is 1.3.0 in `plugin.json` and `marketplace.json`.
- Tests: `epic-dashboard.test.sh` was rewritten (21 cases). Before the change 13 of the first 18 were red, and T13 was
  red before `resolve-task.sh` changed. All six suites are green on the host, in `bash:5`, and from a standalone copy.
- All 9 epics in this repo have the same members under the field as under their old lists, so nothing
  was lost.

## Current State

Completed. Uncommitted: the user commits.
