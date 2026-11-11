---
title: "task: safe migration to git ID allocation (first-run check per clone, duplicate scan, missing-branch warning)"
status: completed
type: feature
priority: medium
epic: task-id-sync
depends-on: [PLUG-125, PLUG-128]
created: 2026-11-11 18:41
tags: ["task-plugin", "git-sync-feature"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | see Implementation (scope reconciled) |
| 20 | Requirements | done | acceptance criteria, sharpened below |
| 30 | Assessment | done | seams: first allocation (no cache), setup |
| 40 | POC | skipped | no unknowns |
| 60 | Architecture | done | reuse PLUG-128 pending/clash path |
| 70 | Tests | done | migration.test.sh (16); red first; regression proven |
| 90 | Implementation | done | task 1.6.0 |
| 100 | Tech Debt | done | nothing new |
| 110 | Reflection | done | id-sources.md; plugin CLAUDE.md/README tests |

## Description

Switching an existing project with several active clones must not produce duplicate IDs (epic decisions).

- **First-run check per clone.** The first allocation in `git` mode in a clone with no `.git/` cache lists the local task files whose IDs are at or above the remote counter and are not on the remote. It marks them pending and syncs them through PLUG-128's mechanism, reporting clashes.
- **Duplicate scan at setup.** Before creating `task-ids`, setup lists any two task files that share an ID and points to the renumbering guide (PLUG-127).
- **Missing-branch warning.** The config says `idSource: git` but the remote has no `task-ids`: a clear warning pointing to setup. Never silent local allocation as if it were synced.
- **Docs:** the migration checklist. Every machine runs the new version first, then the setup command, then the user commits the config change.

Only the first-run check needs PLUG-128. The scan and the warning need only PLUG-125, so they could be peeled off if PLUG-128 stalls.

## Acceptance criteria (draft)

- A second clone with an unsynced local task above the remote counter: its first `git` allocation marks it pending, pushes it, and reports a clash if the number was taken.
- Setup reports existing duplicate IDs before creating `task-ids`.
- `idSource: git` with no remote `task-ids`: a warning that names the setup command.
- Fixture repos only, in Docker.

## Implementation

**Scope reconciled at Context:**
- The missing-branch warning was already delivered and tested in PLUG-125 (R8): an error that names the setup command.
- "Duplicate IDs" cannot mean two files of one name in one clone. Setup now warns about one number under two file names (`X-05.md` + `X-005.md`) and about task files that hold merge-conflict markers (an add/add merge). It warns and never blocks.
- The first-run check turned out to need more than "ids ≥ the counter". A clone's unpushed task can sit *below* the counter, because another clone took that number after the switch. So a clone's own tasks are defined as task files present on **no branch of the remote** (after a fetch).

**Code:**
- `id-git.sh` `idgit_local_only`: fetch the remote, list `ls-tree` of every `refs/remotes/<remote>/*` under the tasks path, and return the numbers of local task files missing from all of them.
- `allocate-id.sh`: on a clone's first git allocation (no cache yet), those numbers join the pending list. PLUG-128's path then claims them or reports them as clashes.
- `id-source.sh` setup: the same, always (adopting is a first use too), plus the two warnings. `numbered_files` is a function, for bash 3.2. The empty `grep -l` is guarded against `pipefail`.

**Tests:** `migration.test.sh` (16 checks). A clone with its own MG-005 (taken meanwhile by another clone) and MG-009: 005 is reported, 009 claimed, the next id is MG-010, the counter 11. Tasks the remote has are not reported. Only the first run checks. Setup in a clone with its own files reports them. Setup warns about `MG-03.md`/`MG-003.md` and about conflict markers. Red first (7 of 16). With the scan disabled, 4 checks fail.

## Current State

Completed 2026-11-11. All suites green on the host, in the container and from a standalone copy. Nothing committed.
