---
title: "task: list shows a Created column, and sort=created orders by it"
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Context | done | read task, root and task CLAUDE.md |
| 2 | Requirements | done | decisions on open questions came with the brief |
| 3 | Assessment | done | sort=created already worked: any field sorts, empty goes last |
| 6 | Architecture | done | one writer (allocate-id.sh), one column helper (created_col) in list-render.awk |
| 7 | Tests | done | task/scripts/test/created.test.sh, 22 cases, seen failing first |
| 9 | Implementation | done | see Implementation below |
| 10 | Tech debt | done | none new |
| 11 | Reflection | done | task/CLAUDE.md suite list, task-format.md, scripts.md, create.md, list.md updated |

## Problem

`/task list` has no column for when a task was created, and task files hold no creation date: 1 of 98 tasks
in this repo has one. To see the backlog's age you have to read file times from the filesystem, which a copy,
a checkout or a clone resets, or ask git, which knows nothing about a task that isn't committed yet.

## Known so far

- `list-render.awk` already sorts by any field (`sort=<field>`, insertion sort). An ISO date sorts correctly
  as a string, so `sort=created` should work once the field exists. Check that it does, and that tasks with
  no date go last.
- The list already drops columns that no task fills, so a project without `created` dates sees no change.
- The date has to be written in exactly one place: `allocate-id.sh`, the only script that creates task files
  (including `--count N` batches). Neither `create.md` nor Claude adds it by hand.

## Acceptance

- A task created with `allocate-id.sh` gets `created: YYYY-MM-DD HH:MM` (local time) in its frontmatter,
  unless the body already has a `created:` line. Batch creation with `--count N` also gets the date.
- `/task list` shows a Created column next to ID when at least one listed task has the date. When none
  does, the table looks as it does today.
- `sort=created` orders tasks oldest first. Tasks with no date go last, ordered by id. `digest` shows the date
  too.
- `created` is listed under Reserved fields in `references/task-format.md`.
- Tests run in the container and on BSD and GNU userland (bash 3.2, no GNU-only `date` flags).
- Version bump and description sync follow the root CLAUDE.md section *Changing an Existing Plugin*.

## Open questions

- Backfill existing tasks? One option is an opt-in script that fills a missing `created:` from the date git
  first committed the file, and skips uncommitted files instead of guessing. The other is to leave old tasks
  blank. Suggestion: ship without a backfill and add the script as a separate task if it's wanted.
- Should the column show the date only, or the date and time? Storing the time costs nothing, and the column
  could show just the date to stay narrow.

## Implementation

- `allocate-id.sh`: `stamp_created` inserts `created: YYYY-MM-DD HH:MM` (local time) before the closing `---` of the
  `--stdin` body unless it has one; text without frontmatter is left alone. `--count N` files are written as a
  frontmatter holding only `created:` instead of empty. Lock, noclobber and nextId code untouched. The clock can be
  set with `TASK_CREATED_NOW`, validated against the date format and never executed (a bad value exits 1).
- `list-render.awk`: `created_col` (date part) feeds a Created column after ID, shown only when a listed task has the
  field, and `created: DATE` in digest. `sort=created` needed no change (full value sorts as a string, undated `~~~` last, then id).
- No backfill. Docs: task-format.md (Reserved fields), create.md, list.md, scripts.md, task/CLAUDE.md, list-tasks.sh `--help`.
- Tests: new `created.test.sh` (22 cases). Seen failing before the change (9 failures; the sort cases already passed).
  Mutation: removing the stamp from the `--stdin` pipe turned 3 cases red, removing the column row output turned 1 red; both restored.
- Results: all 9 suites green on the host and in `bash:5` (with git), incl. the standalone-copy suite.
- Open: version bump, plugin.json, marketplace.json, root README left to the caller.
