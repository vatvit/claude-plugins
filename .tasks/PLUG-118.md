---
title: "task — work with the project folder only (workflow step definitions without ~/.claude)"
status: completed
type: feature
priority: medium
epic: cowork
created: 2026-11-11 18:05
tags: ["task-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | probe without HOME: unset crashes, missing/read-only works |
| 20 | Requirements | skipped | the acceptance criteria are the requirements |
| 30 | Assessment | done | see Context and Assessment |
| 40 | POC | skipped | the probe was enough |
| 60 | Architecture | done | ${HOME:-}, honest message, no shipped steps |
| 70 | Tests | done | config.test.sh: without-HOME section (unset, missing, HOME a file); red before, red again with either fix reverted |
| 90 | Implementation | done | lib.sh task_global_roots ${HOME:-}; resolve-config ~ expansion + honest hint; version bump held |
| 100 | Tech Debt | done | duplicated key/value awk in resolve-config.sh → PLUG-131 |
| 110 | Reflection | done | task/CLAUDE.md Don't regress + test count; references/configuration.md |

## Description

Requirement and decisions: epic PLUG-117, *Decisions, round 2*. Facts about the environment: PLUG-111.
This task no longer waits for PLUG-111. The requirement does not depend on Cowork internals, so it can start now.

What it reads from HOME today (all optional): `project-tasks/config.json`, the global registry, read only when the project has no
`.task-config.json`; `project-tasks/<slug>/`, for tasks kept outside the project; and `project-tasks/_workflow/` (WORKFLOW.md and
`steps/*.md`), the fallback when the project lacks its own workflow definitions (`resolve-task.sh:80-81`, `lib.sh:5-12`).

To decide: where step definitions come from with no HOME. Options: defaults shipped inside the plugin (`${CLAUDE_PLUGIN_ROOT}`,
which is not HOME), vendored into the project, or the one-liners in WORKFLOW.md only. Also: a clear message when the
project has no `.task-config.json` and no global registry is reachable (today it exits 1 and asks).
Related: PLUG-124. If the plugin ships default steps, PLUG-124 may need no work.

## Context and Assessment (2026-11-11)

Probe: an Alpine `bash:5` container, a non-root user, a project with its own `.task-config.json`. The scripts were run with HOME unset,
pointed at a missing dir, and read-only.
- **HOME unset: every script crashes.** `lib.sh:12` (`task_global_roots`, under `set -u`) fails with `HOME: unbound variable`:
  resolve-config, resolve-task, allocate-id. `resolve-config.sh:59` and `:141` (`${val/#\~/$HOME}`) would hit the same error.
- **HOME missing or read-only: everything works** with a project config: resolve, allocate, step lookup. Nothing writes to
  HOME on that path.
- **No project config and no usable HOME:** the error tells the user to add the project to `<HOME>/.claude/project-tasks/config.json`,
  advice they can't follow there (`resolve-config.sh:131`).
- **Step definitions:** the plugin has never shipped any. The global `~/.claude/project-tasks/_workflow/` holds the user's own
  definitions, which are personal and not plugin defaults. Without them the one-liners in WORKFLOW.md apply, as on any fresh install.
- Found on the way, unrelated to HOME: a one-line `.task-config.json` is misread. Filed as PLUG-131.
- Tests: `task/scripts/test/config.test.sh` covers global-registry lookup with `HOME` and `CLAUDE_CONFIG_DIR` and is the place for the new cases.

## Architecture (2026-11-11)

Following root `CLAUDE.md` *Without HOME*:
1. **An unset HOME means no HOME root.** `task_global_roots` uses `${HOME:-}` and skips the `~/.claude` root when it is
   empty. A `CLAUDE_CONFIG_DIR` root still counts. `~` expansion in config values happens only when HOME is set.
2. **The "No config found" message** offers the global registry only when a global root exists. Otherwise it says
   "Create .task-config.json in the project root".
3. **No step definitions shipped with the plugin.** The global steps are the user's own. A project that needs them without HOME
   keeps them in `.tasks/_workflow/steps/` (PLUG-124 does that for this repo). This drops option (a) of the description:
   shipping defaults would be a new feature, not a fallback.
4. Writing to HOME: the only write is creating a global registry, and only when the user chooses one. Nothing changes there.

## Acceptance criteria (common to the project-folder-only sub-tasks of the epic)

- **Project folder only:** with HOME unavailable (unset, missing or not writable) and only the project folder writable, every
  capability works. The exception is a capability the user explicitly chose to keep in HOME: it says plainly that it
  needs HOME and does nothing else.
- **HOME available:** existing behaviour and defaults are unchanged unless the epic says otherwise, and the existing suite passes.
- **Upgrade needs no action:** a user moving from the previous version keeps working with no migration step, no new prompt and no
  lost state. A test runs the new version against state written by the old one (a fixture copied from the current format).
  task: step definitions shipped in the plugin come **last** in the lookup (project, then global, then plugin), so an existing global override keeps winning.
- Tests simulate project-folder-only by running with HOME pointed at a missing or read-only dir, in the Alpine container.
- Plugin Independence: the plugin carries its own fallback logic. No code is shared with another plugin.

## Current State

2026-11-11 18:44. Every step is done. task suite: 9 files green in the bash:5 container and on the host (config 42/42).
**Version bump held (1.5.0 → 1.5.1):** another session has uncommitted task/ changes (tags: create.md, tags.md, CLAUDE.md)
and will probably bump too. Bump once, when the two land together. Not committed.

## Commit note (2026-11-11)

The epic was committed without this task's code. `task/scripts/lib.sh`, `resolve-config.sh`, `config.test.sh`,
`task/CLAUDE.md` and `references/configuration.md` also carry the in-flight git id source work (PLUG-126 and the
tasks around it, task 1.6.0), and in `resolve-config.sh` the `~` fix sits inside that work's `local_values` refactor.
The two cannot be split into a consistent, tested commit, so the PLUG-118 changes go in with the task 1.6.0 commit.
Until then they live only in the working tree.
