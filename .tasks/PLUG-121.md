---
title: "kickoff — work with the project folder only: port registry fallback, and ask before storing ports in HOME"
status: completed
type: feature
priority: medium
epic: cowork
tags: ["kickoff-plugin"]
created: 2026-11-11 18:05
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-117 round 2, PLUG-111; HOME uses listed in Description |
| 20 | Requirements | done | Acceptance criteria in task; decisions of the user as given |
| 30 | Assessment | done | Three task-registry path spellings disagreed; HOME unset crashed under set -u |
| 40 | POC | done | skipped: behaviour verified by tests |
| 60 | Architecture | done | see Design below |
| 70 | Tests | done | kickoff/scripts/test/home.test.sh (75); ports.test.sh setup chooses HOME |
| 90 | Implementation | done | lib.sh helpers, ports.sh scope, defaults/scaffold/inspect/gaps |
| 100 | Tech Debt | done | see Open |
| 110 | Reflection | done | kickoff/CLAUDE.md don't-regress bullet, README, questionnaire, SKILL.md |

## Description

Requirement and decisions: epic PLUG-117, *Decisions, round 2*. Facts about the environment: PLUG-111.
This task no longer waits for PLUG-111. The requirement does not depend on Cowork internals, so it can start now.

What it reads or writes in HOME today: `~/.claude/kickoff/ports.json` (the machine-wide port registry, `ports.sh:25`) and a scan of `$HOME/projects`
(`ports.sh:26`); the optional `kickoff.json` user defaults (`lib.sh:29`); `plugins/installed_plugins.json` (sibling detection,
`lib.sh:60`); and `project-tasks/` (scaffold, inspect, gaps), when tasks are kept outside the project.

Decided (user):
- **The port registry gets a project-folder fallback.**
- **kickoff asks the user whether to keep the port list in HOME.** No silent write to HOME.

To decide: where the answer to that question is recorded (in the project answers, presumably); what the fallback
can promise about collisions when it sees only one project; and sibling detection without `installed_plugins.json`.
**First, as a refactor:** the task-registry path is computed in three places that disagree (`gaps.sh:50`, `scaffold.sh:61`,
`inspect.sh:53`). Move it into one `lib.sh` helper before adding any fallback (PLUG-111, Assessment).

## Acceptance criteria (common to the project-folder-only sub-tasks of the epic)

- **Project folder only:** with HOME unavailable (unset, missing or not writable) and only the project folder writable, every
  capability works. The exception is a capability the user explicitly chose to keep in HOME: it says plainly that it
  needs HOME and does nothing else.
- **HOME available:** existing behaviour and defaults are unchanged unless the epic says otherwise, and the existing suite passes.
- **Upgrade needs no action:** a user moving from the previous version keeps working with no migration step, no new prompt and no
  lost state. A test runs the new version against state written by the old one (a fixture copied from the current format).
  kickoff: an existing `~/.claude/kickoff/ports.json` counts as an earlier "yes, keep ports in HOME", so kickoff does not ask again.
- Tests simulate project-folder-only by running with HOME pointed at a missing or read-only dir, in the Alpine container.
- Plugin Independence: the plugin carries its own fallback logic. No code is shared with another plugin.

## Design

- **Refactor first:** `task_registry_roots` / `task_registry_entry_file` in `kickoff/scripts/lib.sh` replace the three spellings (gaps, scaffold, inspect); semantics mirror the task plugin (CLAUDE_CONFIG_DIR root, then ~/.claude, HOME root skipped when empty), no code shared.
- **HOME usable:** `kickoff_home_usable` creates `~/.claude/kickoff` and a temp file, then removes both again.
- **Where the choice is recorded:** `.kickoff.json` at the project root, `{"ports": "home" | "project"}`, written by `ports.sh scope home|project`. Not a questionnaire question: a new question would change every plan, and the choice is a tool setting, not a project decision.
- **`ports.sh scope`** prints `home`, `project`, `ask` (HOME usable, not chosen, no old registry: the skill asks) or `project-no-home` (nothing to ask). Undecided allocations use the project fallback and write nothing to HOME.
- **Upgrade:** an existing `~/.claude/kickoff/ports.json` with no `.kickoff.json` is `home`, silently (test 7a-7f, old-format fixture).
- **Project fallback:** `.git/kickoff/ports.json` in a git repo (a `.git` file, i.e. a linked worktree, falls to `.kickoff/`), else `.kickoff/ports.json`. It promises no more than: no clash with this registry and with compose files under the project folder; other projects are unseen.
- **Needs HOME, says so, exit 1:** `scope home`, a project that chose home when HOME is gone, `defaults.sh set/unset`, scaffold with R7 "Outside the repo". Reads of kickoff.json / installed_plugins.json fall back to defaults.

## Open

- Switching scope later does not move entries between registries.
- The skill text that asks is untested prose (no test can run the skill).

## Current State

Implemented and verified 2026-11-11: host and bash:5 container, all kickoff suites green (home 75, ports 42, scaffold 59, existing 74, kickoff 113, defaults 18). Red proof: defect reintroduced in a temp copy (HOME trusted when set; CLAUDE_CONFIG_DIR root dropped) turned 9 home cases red. Not released: version bump (kickoff 0.11.0) and marketplace text left to the owner. Previous note: 

Created 2026-11-11 as a Cowork placeholder. Reshaped the same day into a project-folder-only task after the user's round-2 decisions. Not started.

## Review (epic coordinator, 2026-11-11)

- Re-ran `kickoff/scripts/test/all.sh` on the host and in `bash:5`: defaults 18, existing 74, home 75, kickoff 113,
  ports 42, scaffold 59, all failed 0 on both.
- Independent red check, different from the implementer's: in a temp copy, `current_scope` answered `home` instead of
  `ask` for an undecided project with a usable HOME (i.e. write to HOME unasked). home.test.sh: 4 red (6a, 6c–6e).
- The scope-switch gap in *Open* is accepted for now: switching is rare, and the old registry is left intact, not lost.
- Release: kickoff 0.10.2 → 0.11.0 (new `ports.sh scope` command), done with the epic's release step.

## Bug found at commit time (2026-11-11)

The pre-commit run of the staged snapshot failed `ports.test.sh` 4a/4b/4d in 1 run of 3 (git-enabled container).
`kickoff_home_usable` created `~/.claude/kickoff` when it was missing and removed it again after probing. A concurrent
probe then found the dir gone and called HOME unusable, so one of eight parallel allocations was refused. The same race
also left the dir behind, which broke "nothing written to HOME unasked".
- Red first: new home.test 8a/8b (twenty concurrent probes on a fresh HOME; all usable, HOME left empty). Before the
  fix 8b failed in 4 of 5 host runs.
- Fix: the probe never creates or removes the shared dir. It writes a temp file in it when it exists, and otherwise a
  temp dir of its own in the nearest existing ancestor; an ancestor that is a file means no.
- After the fix: the suite is green on the host and in `bash:5`. Repeated 8× ports + 8× home in the git image and 5× home on the host, all green.
