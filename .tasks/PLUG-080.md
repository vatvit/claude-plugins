---
title: task — optional `tags` on a task, and /task list filters by tag
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | parser, filter, renderer read; repeated field= already ANDs |
| 20 | Requirements | done | EARS R1–R9 below |
| 30 | Assessment | done | ready; one write helper to extract |
| 40 | POC | skipped | no risky unknown; the awk is small and dual-target tested |
| 50 | Domain | skipped | no domain model; a list of labels |
| 60 | Architecture | done | below |
| 70 | Tests | done | tags.test.sh, 48 cases, written first and seen red; mutation-checked |
| 80 | Subtasks | skipped | one small slice |
| 90 | Implementation | done | below; task 1.3.0 -> 1.4.0 |
| 100 | Tech Debt | done | PLUG-081 (shared test helpers, 7 copies) |
| 110 | Reflection | done | plugin docs updated with the code; exec-bit memory extended |

## Description

A task can carry an optional `tags` field: a simple array of strings, e.g.

```yaml
tags: ["performance", "milestone 2", "three of several words, and with comma"]
```

The user wants to label tasks across epics and types ("performance", "milestone 2",
"asset-generation") and then list only the tasks with a given tag.

Today any free field can already be filtered with `field=` / `field~`, but that compares the
whole value as one string: `tags=performance` would not match `[performance, milestone 2]`,
and `tags~mile` would match by substring of the raw text. Tags need element membership.

## Scope

- `tags` becomes a reserved field in `references/task-format.md`: optional, an array of
  strings, a tag may contain spaces.
- Instructions: how to write tags (create, and adding/removing a tag on an existing task —
  allowed in flight, as it is metadata, not history), and how to filter.
- `read-tasks.sh` / `list-tasks.sh`: filter by tag with element membership, OR within the
  filter, AND across fields as today; `tags=_` for untagged tasks.
- `/task list` output shows the tags when any listed task has them (dropped otherwise, like
  other empty columns).
- `/task show` shows the tags.
- SKILL.md trigger phrases ("tag", "tagged", "filter by tag", "list tasks with tag …").
- Version bump and marketplace sync (CLAUDE.md *Changing an Existing Plugin*).

## Decisions (agreed with the user 2026-10-23)

1. **Syntax:** one form only, a flow array of double-quoted strings:
   `tags: ["one", "two", "three of several words, and with comma"]`. Quoting is what lets a
   tag contain spaces and commas. No block list, no bare comma string.
2. **Case:** tags are lowercase only. Written lowercase; matching ignores case, so a stray
   `Performance` still matches `performance`.
3. **`group=tags`:** a task with several tags appears in every one of its tags' groups.
4. **Duplicates:** when a tag is added that looks like an existing one (`perf` vs
   `performance`, `milestone-2` vs `milestone 2`), Claude names the existing tag and asks which
   to use. This needs a way to list the tags in use across the task set.
5. **task-roadmap:** out of scope, no tags there.

6. **Filter syntax:** a comma means OR (`tags=performance,ui`), a tag with a comma or space is
   quoted (`tags="three of several words, and with comma"`), and a repeated `tags=` means AND
   (`tags=performance tags="milestone 2"`). Check at Requirements that it fits the existing
   `list-tasks.sh` argument parsing.
7. **Claude tags tasks itself, but only with existing tags.** When creating or shaping a task,
   Claude adds a tag that is already in use whenever the task clearly fits it; the user does
   not have to name it each time. Claude never creates a new tag on its own: a new tag needs
   the user's request or an explicit OK. When unsure whether an existing tag fits, Claude asks.

## Requirements

- **R1** Where a task's frontmatter has `tags:`, `read-tasks.sh` shall decode it as a list: a flow
  array of double-quoted strings, commas inside quotes kept. Unquoted elements (`[a, b]`) are
  read leniently, split on commas. Each element is trimmed and lowercased; empty elements and
  duplicates are dropped. An empty list is the same as no field.
- **R2** `read-tasks.sh --records` (and so `resolve-task.sh`) shall carry the list in one
  canonical form, `["a", "b"]`; JSON mode shall emit a real JSON array.
- **R3** When `/task list` gets `tags=v1,v2`, it shall list the tasks having any of the values,
  case-insensitively; a double-quoted value keeps its spaces and commas
  (`tags="three, with comma"`). `tags=_` lists the tasks with no tags. `tags~s` matches a
  substring of any one tag.
- **R4** When `tags=` is given more than once, a task shall pass only if every one matches (AND).
- **R5** When `group=tags`, each tag shall be a group, a task with several tags shall appear in
  each, tasks with none go to `(no tags)` last; a summary's total counts each task once.
- **R6** When any listed row has tags, the table shall show a Tags column (`a, b`); otherwise none.
- **R7** `tags.sh list` shall print every tag in use (all tasks, closed included) with its count;
  this is what Claude reads to reuse tags and to spot near-duplicates.
- **R8** `tags.sh add <id> <tag>...` shall refuse a tag not yet in use unless `--new` is given,
  and name the refused tags; `--new` is passed only on the user's request or OK (decision 7).
  `tags.sh remove <id> <tag>...` drops tags; the last one removed drops the line. Writes are
  lowercase, canonical, atomic and diff-guarded. A tag containing `"`, `\` or a control
  character is rejected.
- **R9** A task without `tags` shall behave exactly as before in every command.

## Assessment

Ready. `set-status.sh` has the plugin's only frontmatter writer (`write_status`, status line
only); `tags.sh` needs the same write for another key. Extract it once into `lib.sh` as
`task_fm_set` and have both use it, rather than a second copy. The renderer splits filter values
with a plain `split(…, ",")` in `passes()`; that becomes a quote-aware split used by every field.

## Architecture

- **Decoding in the one parser.** `read-tasks.sh` decodes `tags` (R1) and emits the canonical
  `["a", "b"]`. A tag cannot contain `"`, so consumers split that form on the regex `", "`
  after stripping `["`/`"]`: no second parser of the raw YAML anywhere. Only `tags` is decoded;
  other `[...]` values stay strings, as today.
- **Renderer** (`list-render.awk`): `fvals()` quote-aware filter split; `tagsof(id, arr)` splits
  the canonical form; `passes()` uses element membership for a list field; `collect_groups()`
  puts a task in every one of its tags' buckets; `group_hint()` quotes a value with a space or
  comma; Tags column in `print_out()`. `is_list(f)` (`f == "tags"`) is the one place that
  names the list field.
- **`tags.sh`** (new): `list | add | remove`, reading through `read-tasks.sh`, writing through
  `task_fm_set`. Params are data only: an action from a fixed set, tags as quoted values.
- **`lib.sh`**: `task_fm_set <file> <key> <value> [--require]`, value passed through
  `ENVIRON` (no awk `-v` escape processing); empty value removes the line; absent key is
  inserted before the closing `---`; `--require` keeps set-status's "no status field" error.
- **Prose:** `task-format.md` reserved field; `create.md` + a short `references/tags.md`
  (the one home of the tagging rule: reuse existing tags that clearly fit, never a new one
  without the user, ask when unsure or near-duplicate); `list.md` and `show.md` point at it.
  "Untagged" (= no epic) reworded to "without an epic".

## Context

**Epic:** none. **Prior tasks:** PLUG-077 (task 1.3.0) made `epic:` the only membership source and
moved list logic into scripts; nothing earlier touched tags. No rejected task on the subject.

**Plugin rules that bind this change** (`task/CLAUDE.md`):
- **One parser.** Frontmatter is read only in `read-tasks.sh`; do not start a second one.
  Tag parsing (the quoted array) belongs there or in the one consumer, not in several places.
- **Prose is for judgement, scripts are for work.** Filtering, listing the tags in use and a
  frontmatter write are scripts with tests; whether a tag fits a task, and near-duplicate
  detection, stay with Claude.

**Code to touch:**
- `task/scripts/read-tasks.sh` — awk reads `key: value` lines in the first 25 lines, strips one
  pair of surrounding quotes. `tags: ["a", "b"]` starts with `[`, so it arrives as the raw
  string `["a", "b"]` (JSON-escaped in JSON mode). No array support today.
- `task/scripts/list-tasks.sh` — argument parsing. Each `field=v1,v2` becomes one `#F` record;
  values split on `,` in the renderer.
- `task/scripts/list-render.awk` — `passes()` loops over all `#F` records and requires each:
  **a repeated `tags=` is already AND, for free** (decision 6). Needed: quote-aware split of
  the filter values (a quoted tag may contain a comma), element membership + lowercase for
  `tags`, multi-group membership in `collect_groups()` for `group=tags` (today one task → one
  bucket), a Tags column in `print_out()` dropped when no row has tags (same as Priority/Epic).
- `task/skills/task/references/task-format.md` — reserved-fields table gains `tags`.
- `task/skills/task/commands/create.md`, `list.md`, `show.md`; `references/scripts.md`;
  `SKILL.md` description + command line; `plugin.json`, marketplace entry, root README.
- `resolve-task.sh` prints every frontmatter field, so `/task show` gets `tags=` without code.

**Naming clash to fix:** "untagged" already means *without an epic*, in `list.md:19`
("no untagged tasks"), `list-tasks.sh:75,126`, `epic-dashboard.sh:66`, and 11 times in
`list-tasks.test.sh`. With real tags it becomes ambiguous; reword those to "without an epic".

**Neighbour:** task-roadmap reads the task files with its own awk and knows `depends: [A, B]`
(unquoted flow array). It reads named keys only, so a `tags:` line is ignored there; no change
(decision 5).

**Tests:** `task/scripts/test/list-tasks.test.sh` (41 cases, fixture builder `task()`), run on the
host and in a `bash:5` container (busybox awk) — the container run is mandatory, since
`list-render.awk` is the largest awk program here. Also `port.test.sh` (standalone copy).

**Parallel-session collisions:** the running crew works on delay and kickoff; PLUG-079 is
docs-manager. Nothing else touches `task/`.

## Acceptance criteria

- A task without `tags` behaves exactly as today in every command.
- `/task list tags=performance` lists exactly the tasks whose `tags` contains
  `performance`, including one whose other tag is `milestone 2`.
- A tag with a space (`milestone 2`) or a comma can be filtered on.
- `/task list tags=_` lists the untagged tasks.
- `/task list tags=PERFORMANCE` matches `performance`.
- `/task list group=tags` puts a two-tag task in both groups.
- Adding a near-duplicate tag makes Claude ask, naming the existing tag.
- On `/task create`, a task that clearly fits an existing tag gets it without being asked;
  a tag not yet in use is never added without the user's OK.
- Tag filters combine with other filters (`tags=performance status=proposed`).
- Bash 3.2, BSD + GNU/busybox awk; tests in the task plugin suite, run in Docker.

## Tests

`task/scripts/test/tags.test.sh` — 48 cases over R1–R9, written before the code: 36 red at first.
Each of five deliberate defects (no `--new` guard, plain comma split, summed summary total, no
lowercasing, unquoted group hint) turns at least one case red.

## Implementation

- `read-tasks.sh`: `decode_tags()` → canonical `["a", "b"]` in records, a JSON array in JSON mode.
- `list-render.awk`: `is_list` / `listof` / `fvals` (quote-aware filter split, all fields) /
  `matches`; `passes()` element membership; `collect_groups()` multi-bucket; `group_hint()`
  quotes; Tags column; summary total = tasks, not group sum.
- `tags.sh` (new): `list`, `add [--new]`, `remove`.
- `lib.sh`: `task_fm_set`, now also behind `set-status.sh`'s status write (its own copy removed).
- "untagged" (= no epic) reworded in `list-tasks.sh`, `epic-dashboard.sh`, `list.md`, the list tests.
- Prose: `references/tags.md` (new, the tagging rule's one home), `task-format.md`, `create.md`,
  `list.md`, `show.md`, `scripts.md`, `SKILL.md` triggers, `list-tasks.sh --help`, task
  `CLAUDE.md` + `README.md`, root `README.md`; `plugin.json` + marketplace 1.3.0 → 1.4.0.

## Current State

Completed 2026-10-23. All seven task suites green on the host (bash 3.2, BSD) and in `bash:5`
(busybox); the worktree suite run in Alpine with git. Not committed. Follow-up: PLUG-081.

