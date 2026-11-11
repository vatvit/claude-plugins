---
title: "task: renumber a task ID and fix its references (guide + script)"
status: completed
type: feature
priority: medium
epic: task-id-sync
created: 2026-11-11 18:41
tags: ["task-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | see Context |
| 20 | Requirements | done | R1–R8 |
| 30 | Assessment | done | ready |
| 40 | POC | skipped | file moves + text replace, no unknowns |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | renumber.test.sh (22); red first; boundary checks proven to fail |
| 90 | Implementation | done | renumber.sh + one id matcher in lib.sh + guide |
| 100 | Tech Debt | skipped | no shortcut taken; merge-conflict case is a documented manual procedure by design |
| 110 | Reflection | done | plugin CLAUDE.md layout + tests; task-format reserved field |

## Description

Duplicate IDs are already possible today in `local` mode (two clones, a merge), and `task-id-sync` reports clashes that the user must resolve. Both need one way to change a task's ID safely. This is the shared reference the other slices of the epic link to for every clash.

Deliver a user-facing guide in the task plugin docs, and a `renumber` script if Requirements confirms it is worth it: move `PREFIX-OLD.md` to a freshly allocated ID and its artifacts folder, rewrite references (`depends-on`, mentions in other tasks, epic index), and leave a note in the renamed task saying what it used to be called.

Independent of the git work: it can start now, in parallel with PLUG-125.

## Acceptance criteria (draft)

- Given two task files with one ID, following the guide (or running the script) leaves two distinct IDs, with every reference in other tasks pointing to the right one.
- The new ID comes from `allocate-id.sh`, never computed.
- The script, if built: bash 3.2, BSD+GNU, no `sed -i`, idempotent, and tested in Docker on fixture task sets.

## Context

- **Where a clash really comes from.** One directory cannot hold two files named `PLUG-050.md`. A clash appears either *before* a merge (my local `PLUG-050.md` and the remote's `PLUG-050.md` are different tasks) or *during* one (git reports an add/add conflict on that path). Either way the fix is the same: move one task to a fresh id. The second case first needs both versions out of the conflict, which belongs in the guide, not in a script.
- **References are ambiguous.** After a clash, a mention of `PLUG-050` in another task may mean either task, so a script cannot rewrite them blindly. Which ones to rewrite is a judgement. The script lists the references and rewrites only the tasks it is told to (plugin rule: prose for judgement, scripts for work).
- **Ids grow past 999** (`PLUG-1000.md`, task-format.md), so replacing `PLUG-100` must not touch `PLUG-1000`: a boundary-aware match.
- **Reuse:** the new id comes from `allocate-id.sh --stdin`. That respects `idSource` (git or local) and keeps the existing `created:` line. Frontmatter writes go through `task_fm_set`, and the epic index through `update-epic-index.sh`.
- Reserved fields (task-format.md) gain `renumbered-from`.

## Requirements

- R1: `renumber.sh <project-dir> <OLD-ID> [--update <ID>...]` moves task OLD to an id allocated by `allocate-id.sh`, and prints `old=`, `new=`, `path=`.
- R2: The moved task keeps its content and `created:`. Its own mentions of OLD become NEW, and it gains `renumbered-from: OLD`.
- R3: The artifacts folder `<tasksDir>/<OLD>/` moves to `<tasksDir>/<NEW>/`.
- R4: Mentions of OLD in the tasks named by `--update` become NEW (the `depends-on` lists and the text). No other file is changed.
- R5: Every other task file still mentioning OLD is reported as `ref=<ID>:<line>`, so the caller can decide.
- R6: Replacement is boundary-aware: `X-100` never matches inside `X-1000` or `AX-100`.
- R7: Renumbering an epic rebuilds `_epic-index.json`.
- R8: A missing OLD, a malformed id, or an `--update` id that does not exist fails before anything is allocated or changed.

## Architecture

- `scripts/renumber.sh`. Validate everything first (R8). Then allocate: the old body with OLD → `{{ID}}` (boundary-aware awk) piped to `allocate-id.sh --stdin`. Then `task_fm_set renumbered-from`, `mv` the artifacts, remove the old file, rewrite the `--update` files, rebuild the index if the task is an epic, and print the refs.
- One awk replacer function in `lib.sh` (`task_id_replace <file> <OLD> <NEW>`: tmp + mv, diff-guarded), used both for the moved task and for the `--update` files.
- The guide is `references/renumber.md`: both clash cases, and how to get both versions out of an add/add conflict. `id-sources.md` links to it.

## Tests

`task/scripts/test/renumber.test.sh` (22 checks): refusals change nothing (missing id, malformed id, unknown `--update` id); a move keeps the content and `created:`; own mentions and the title follow; `renumbered-from` is set; the artifacts move; `--update` rewrites `depends-on` and text; an unnamed task is untouched and reported as `ref=`; `RN-100` vs `RN-1000`; the epic index follows. Red first (19 of 22 failed before the script existed). With the boundary check removed, the two boundary checks fail.

## Implementation

- `task/scripts/renumber.sh`: validate all ids first. Allocate through `allocate-id.sh --stdin`, so `idSource` is honoured and `created:` kept. Set `renumbered-from`, move the artifacts, remove the old file, rewrite the `--update` tasks, rebuild the epic index, print the refs.
- `task/scripts/lib.sh`: `_task_id_awk` is the one id matcher (boundary-aware, `index`-based). `task_id_replace` and `task_id_lines` sit on top of it. A second copy inside `renumber.sh` was removed before finishing.
- Guide `task/skills/task/references/renumber.md`: which task moves, a clash before a merge, and an add/add conflict during one. Linked from `id-sources.md`, `SKILL.md` (row and triggers), `scripts.md`, `task-format.md` (new reserved field `renumbered-from`), the plugin `README.md` and `CLAUDE.md`. Ships in task 1.6.0 with PLUG-125, and the manifests' descriptions mention it.

## Current State

Completed 2026-11-11. All suites green on the host, in the container and from a standalone copy. Nothing committed.
