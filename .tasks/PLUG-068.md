---
title: crew — Docker in a worktree — a read-only compose report, and the slot rule for worktree runs
status: completed
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | B (folder = project name) came with PLUG-065: crew_wt_dir names the folder <repo>-<name> |
| 20 | Requirements | skipped | acceptance criteria are the spec |
| 30 | Assessment | done | compose config always prints name:, so a name is a trap only when it differs from the folder-derived one |
| 40 | POC | skipped | fixtures hand-written in the normalized format; no docker run needed |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | compose-report.awk + compose_report in lib.sh (PLUG-066 task worktrees will call it too); one call in copy_new |
| 70 | Tests | done | docker.test.sh, 16 cases, a docker stub on PATH; red before (7 failed), red with the call site or the port rule removed |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | all 14 crew suites green on host (BSD awk) and crew-test (busybox) |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | crew CLAUDE.md (layout, design rule), slots.md section, SKILL rule 7, README |

## Description

Part of PLUG-062 (epic `crew-worktrees`). The user chose Docker options B + C + D there. crew
never writes, wraps or rewrites a project's Docker setup. B (the folder name as the project name)
comes with PLUG-065. This task is C and D.

## Scope

- D: `compose-report.awk` reads `docker compose config --no-interpolate` (read-only) and prints,
  once, what defeats B or C:
  - a top-level `name:`;
  - `container_name`;
  - a fixed tag on a built image;
  - host ports, including those of the services a `run` starts;
  - mounts outside the project.

  It is silent without docker or a compose file. For a project that cannot run two copies, it
  advises running Docker only from the main tree.
- C, skill rule only: in a worktree, a Docker run with no host ports takes a `cpu` slot; one that
  publishes host ports takes `exclusive`. Also note that a one-off unnamed container
  (`docker run --rm`, mounting the worktree, no `--name`, no `-p`) is isolated already, and list
  its traps: the mount, fixed image tags, named volumes.
- `references/slots.md` and SKILL.md rule 7.

## Acceptance criteria

- The awk part is tested on fixture compose configs (normalized output saved as test data), on
  BSD awk and busybox: every trap is named; a clean config prints nothing.
- No docker means no output and exit 0.

## Notes

- Needs nothing for the report itself. The call site in worktree creation is a one-line
  addition after PLUG-065.

## Current State

Implemented (2026-10-16), not committed. No crew version bump (the epic bumps once).

## Implementation (2026-10-16)

- `crew/scripts/compose-report.awk` (D): reads the normalized YAML and names a `name:` other than
  the folder-derived one, `container_name`, `image:` on a built service, host ports (long form
  `published:` and short `host:container`), bind mounts outside the folder, and `external: true`
  volumes. Values naming `COMPOSE_PROJECT_NAME` already differ per copy and are skipped. Silent
  when clean; otherwise it ends with the advice to run Docker from the main tree only.
- `compose_report <dir>` (lib.sh): no compose file (and no `COMPOSE_FILE`), no docker, or a
  failing `docker compose config` means no output and exit 0. Called once at the end of `copy new`.
- C is a skill rule: `references/slots.md` "Docker in a copy", and SKILL.md rule 7.
- Fixtures `crew/scripts/test/compose/{clean,traps}.yml` and `traps.out` are hand-written in the
  format `docker compose config` prints; no real docker ran.
