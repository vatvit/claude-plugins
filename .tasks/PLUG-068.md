---
title: crew — Docker in a worktree — a read-only compose report, and the slot rule for worktree runs
status: approved
type: feature
priority: medium
epic: crew-worktrees
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

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

Approved (2026-10-16). Nothing changed in code.
