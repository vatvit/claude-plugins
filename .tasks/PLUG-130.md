---
title: "task: switch a project back from git to local ID allocation"
status: completed
type: feature
priority: low
epic: task-id-sync
depends-on: [PLUG-125]
created: 2026-11-11 18:41
tags: ["task-plugin", "git-sync-feature"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | id-source.sh, id-git.sh cache, task_config_edit |
| 20 | Requirements | done | acceptance criteria below; idSource is removed (local is the default) rather than set |
| 30 | Assessment | done | small: one subcommand + a numeric op in the config writer |
| 40 | POC | skipped | no unknowns |
| 60 | Architecture | done | reuses idgit_reserve/settle; one config writer gains `num` |
| 70 | Tests | done | switch-back.test.sh 18 cases, red first; claim and last-fetched checks proven red |
| 90 | Implementation | done | all suites green: host, task-test container, standalone copy |
| 100 | Tech Debt | done | none new; timeouts are PLUG-133 |
| 110 | Reflection | done | id-sources.md, scripts.md, README, CLAUDE.md, SKILL triggers |

## Description

Leaving `git` mode must be as safe as entering it. The command reads the remote counter (syncing pending IDs first, if reachable), writes it into `nextId` in `.task-config.json`, sets `idSource: local`, and clears the `.git/` cache. It edits the config but never commits it, and it never deletes the remote `task-ids` branch (the user decides that).

## Acceptance criteria (draft)

- After switching back, the next local allocation continues from the remote counter, with no reuse.
- Pending IDs are synced first when the remote is reachable. Otherwise the user is told which IDs are unsynced.
- The remote `task-ids` is left untouched.

## Implementation (2026-11-11)

- `id-source.sh <project-dir> local`. When the remote is reachable, it claims the pending ids with `idgit_reserve` (count 0) and `idgit_settle`; a clash is warned about as usual and listed as "still to check". `nextId` = max(remote counter, highest task file + 1, cache). Offline, it uses the counter from the last fetch (`refs/remotes/<remote>/<branch>`) and names the ids it never synced. Then `task_config_edit num nextId … del idSource`, and the clone's cache is deleted. It never commits and never touches `task-ids`. On a project already local it does nothing.
- `task_config_edit` gained `num <key> <digits>` (a bare integer); it is still the one config writer.
- One deviation from the description: `idSource` is removed rather than set to `local`, since local is the default and the config ends up as it was before the switch.
- Test lesson: "the counter reached N" did not prove pending ids were claimed, because the floor alone raises the counter. The test now uses a real clash, which goes red without the claim.
- Docs: id-sources.md *Switching back to local* (also: switch online, pull the change into every clone soon), scripts.md row, README, CLAUDE.md, a SKILL trigger.

## Current State

Completed 2026-11-11, in task 1.6.0, not committed. switch-back 18/18, and every suite is green on host, container and standalone.
