---
title: "task: offline fallback for git ID allocation (pending sync, push later, report clashes)"
status: completed
type: feature
priority: medium
epic: task-id-sync
depends-on: [PLUG-125]
created: 2026-11-11 18:41
tags: ["task-plugin", "git-sync-feature"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | builds on PLUG-125 cache + reserve; renumber from PLUG-127 |
| 20 | Requirements | done | acceptance criteria below were sufficient |
| 30 | Assessment | done | seams: idgit_reserve, the cache, allocate-id persist step |
| 40 | POC | skipped | no unknowns |
| 60 | Architecture | done | see Implementation |
| 70 | Tests | done | offline.test.sh (24); red first; regression proven |
| 90 | Implementation | done | task 1.6.0 |
| 100 | Tech Debt | done | nothing new; timeouts already PLUG-133 |
| 110 | Reflection | done | id-sources.md, scripts.md, plugin CLAUDE.md/README |

## Description

In `idSource: git` mode, when the remote is unreachable, allocate locally from the `.git/` cache as a normal `PREFIX-NNN` and record it as *pending sync* (epic decisions). The next allocation that reaches the remote first pushes the pending IDs. If the remote counter already passed a pending ID, report the possible clash and point to the renumbering guide (PLUG-127).

Documents its own failure cases: what *pending* means, how to force a sync, and what to do with a reported clash.

## Acceptance criteria (draft)

- Remote unreachable: the task is created at once with a normal ID, marked pending.
- The next online allocation pushes the pending IDs first, in one push where possible.
- A pending ID the remote already passed is reported, with a pointer to the renumbering guide, never silently kept.
- Tested against a fixture bare remote made unreachable, in Docker.

## Implementation

- **Cache** (`<git common dir>/task-ids/<PREFIX>.cache`): `nextId=`, plus `pending=` and `clash=` lines. `id-git.sh` gained `idgit_cache_list`, `_save`, `_forget`, `idgit_settle` (after a push: pending cleared, clashes kept and warned about, nextId follows the remote) and `idgit_add_pending`.
- **`idgit_reserve`** takes the pending list. A pending id at or above the remote counter raises the counter past it. One below it becomes `clash=`. Both are worked out again on every retry, against the counter the push is actually based on. They are claimed in the same push as the new reservation.
- **`allocate-id.sh`**: offline with a repo records the new ids as pending (the warning says so). Online, it hands the pending list to the reservation and settles afterwards. With no repo, it warns only, because there is no cache to record in.
- **`id-source.sh`**: `sync` claims pending ids with no task created, and fails while offline. `status` lists `pending=` and `clash=`. Setup also claims pending ids.
- **`renumber.sh`**: moving a task forgets its old number from pending and clash.
- **Tests:** `offline.test.sh` (24 checks): pending recorded; claimed in one push; a clash reported, kept and cleared by renumber; `sync` online, offline and repeated. Red first. With the pending list not passed, the clash checks fail.
- **Docs:** `id-sources.md` has a new *Offline: pending ids* section and three troubleshooting rows; `scripts.md`, plugin `README.md` and `CLAUDE.md` are updated.
- **A clash is reported as *possible*.** The other clone may have spent the number on a task that never reached the remote, so the user checks before renumbering. Detecting it exactly would need the remote's task files, and they live on another branch.

## Current State

Completed 2026-11-11. All suites green on the host, in the container and from a standalone copy. Nothing committed. PLUG-129 is unblocked.
