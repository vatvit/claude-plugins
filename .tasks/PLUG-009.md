---
title: Task list and status rendering move from prose into scripts
status: completed
type: refactor
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | Plugin CLAUDE.md + all 7 scripts + both suites read; the invariants port.test.sh pins shaped the design. See ## Context |
| 20 | Requirements | skipped | Scope and acceptance criteria in this file are the spec; nothing to restate in EARS |
| 30 | Assessment | done | Frontmatter parsed in 5 places; port.test.sh forbids the literals a session-storage script would need. See ## Assessment |
| 40 | POC | skipped | Nothing unknown — bash+awk rendering of a format already written down |
| 50 | Domain | skipped | No new terms; PLUG-008 already fixed the vocabulary |
| 60 | Architecture | done | D1-D6; D2 (one parser) and D4 (storage handed in, never named) are the load-bearing ones. See ## Architecture |
| 70 | Tests | done | 2 new suites, 67 cases; 97 total, green on host and busybox. See ## Tests |
| 80 | Subtasks | skipped | One slice, done alongside PLUG-010 as the user asked |
| 90 | Implementation | done | 4 new scripts, 5 rewritten; SKILL.md prose replaced. See ## Implementation |
| 100 | Tech Debt | done | No tickets: nothing was shortcut. Two judgement calls recorded instead. See ## Tech Debt |
| 110 | Reflection | done | task/CLAUDE.md gained One parser and Prose vs scripts; README + plugin.json + marketplace synced |

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

## Context

The plugin's own `CLAUDE.md` is the orientation document here, and two of its "don't
regress" entries decided the design before any code was written: *session-storage is
optional and detected, never required*, and *`allocate-id.sh` is the only path to an id*.

`port.test.sh` turns the first into a literal scan — no shipped script may contain the
string `storage.sh` or a sibling plugin's directory name. That is a hard constraint on
`session-active.sh`, which is exactly the script that has to talk to that helper.

Prior art: PLUG-008 built this plugin and left both follow-ups (this task and PLUG-010)
with their dependency order spelled out. It also left the scripts untouched from the old
repo — including five copies of the frontmatter parser.

## Assessment

- `SKILL.md`: 1036 lines. `### LIST` 223, `### DO` 146, session-storage rules 53.
- The same YAML frontmatter awk block appears in `read-tasks.sh`, `resolve-task.sh`,
  `resolve-epic.sh`, `update-epic-index.sh` and `epic-dashboard.sh` — five copies, with
  three different quote-stripping behaviours between them. Adding `list-tasks.sh` on top
  would have made six.
- `update-epic-index.sh` wrote its output unconditionally, against the repo's diff-guard
  rule.
- Two contradictions in the prose, which a script cannot carry forward:
  - the append/switch/cancel prompt says to set the parked task to `on-hold`, which is not
    one of the six valid statuses;
  - "flat table sorted by ID" versus "default sort: priority, then ID".

## Architecture

- **D1 — one renderer, one call.** `list-tasks.sh` prints the finished table. The skill
  passes the user's arguments through and prints the result; it does not re-sort or re-pad.
- **D2 — one parser.** `read-tasks.sh` gains `--records` (TSV `id<TAB>key<TAB>value`) and
  `--id=`, and becomes the only frontmatter reader. `resolve-task.sh` builds id resolution
  and the workflow table on top of it; the other three scripts consume one of those two.
  This is the repo's "awk emits tab-separated typed records" convention, and it is why
  the renderer needs no JSON parsing.
- **D3 — config and filters travel as input, not as `-v`.** Everything the renderer needs
  arrives in one stream (`#C` config, `#F` filters, `#E` epic index, `#V` epic views, then
  records), which sidesteps awk's `-v` quoting limits entirely.
- **D4 — the storage helper is handed in, never named.** `session-active.sh` reads
  `TASK_STORAGE_BIN` and `TASK_SESSION_ID` from the environment and execs that path. No
  shipped script contains the helper's filename or its plugin's directory name, so the
  independence scan still holds and the plugin still works with nothing installed
  (`status=unavailable`, exit 0).
- **D5 — a conflict is reported, never resolved.** `session-active.sh add` refuses to
  append when an unrelated task is active: it prints `status=conflict` and writes nothing.
  Append/switch/cancel is the user's call, so it stays in prose — the script only makes
  the two outcomes executable (`--force`, `set`).
- **D6 — the two contradictions resolved.** `on-hold` is gone: switching makes the new task
  the only active one and leaves the others' status alone, with `blocked` offered if the
  user wants them parked. Flat lists stay id-ordered unless `sort=` says otherwise.

## Tests

`scripts/test/list-tasks.test.sh` (41) and `scripts/test/status-session.test.sh` (26), in
the style of the existing suites — plain bash, no dependencies, fixtures built in `mktemp`.
Each case pins one documented rule, so the suite reads as the spec the prose used to be:
the smart `,_` default, the closed-sub-task collapse and its exact count line, open
sub-tasks never collapsing inside an epic, the >5 rule with its drill-down hint, auto-group
past 15, the Epic column's `[Epic]`/id forms, the parent-epic cascade, the conflict that
writes nothing.

The storage helper in the status suite is a five-line stand-in, which is the point: the
plugin talks to whatever executable it is handed, and the same suite proves it survives
having none.

`port.test.sh` gained two cases (19): the renderer runs from the isolated copy, and
`session-active.sh` is a no-op with no helper set.

Totals: 97 cases, green on the host (BSD awk) and in `bash:5` (busybox awk).

## Implementation

New: `list-tasks.sh` + `list-render.awk`, `set-status.sh`, `session-active.sh`.
Rewritten: `read-tasks.sh` (records mode, single awk pass, indexed-array file list rather
than `xargs`, which could have split one JSON array into several).
Now delegating instead of parsing: `resolve-task.sh`, `resolve-epic.sh`,
`update-epic-index.sh` (also diff-guarded now), `epic-dashboard.sh` (also gained a single
`json_escape`).

Two things worth knowing next time:

- `port.test.sh` scans for literals, so a *comment* saying "never `sed -i`" fails the
  "no in-place sed" check. Explain the rule without spelling the flag.
- An awk `exit` mid-pipeline SIGPIPEs the producer, and `set -euo pipefail` turns that into
  a failed script. The scan in `resolve-epic.sh` uses a `found` flag instead.

## Tech Debt

No tickets. Nothing was shortcut, and the three duplications the task named are gone: the
`read-tasks.sh` flag list now lives in its `--help`, epic detection in `references/epics.md`,
the closed-collapse rule in the script plus its test.

Two judgement calls are recorded here rather than as debt:

- The active-task marker (`* ` before the id) is new. The prose said "mark the active task
  IDs" without saying how.
- `summary` ignores epic references — it is a counts overview of the filtered set. The
  prose never combined the two.

## Current State

Done. 97 tests green on both targets; all seven commands walked end to end against this
repo's `.tasks/`. Shipped together with PLUG-010 as one change: `task` 1.0.0 → 1.1.0,
marketplace entry synced.
