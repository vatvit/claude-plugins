---
title: "crew: working coordinator — the coordinator may take a task of its own (hint with one worker)"
status: completed
type: feature
priority: medium
tags: ["crew-plugin"]
created: 2026-11-17 17:59
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | crew/CLAUDE.md, SKILL.md Roles, status.sh, session-start.sh, task.sh, holds.sh |
| 20 | Requirements | skipped | scope + acceptance criteria above suffice |
| 30 | Assessment | done | the scripts already let the coordinator own a task; guards do not exempt it |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | one helper `working_note` in lib.sh, used by status and SessionStart |
| 70 | Tests | done | `working.test.sh` (13 checks); seen red before the code and on a mutation (-eq 1 → -ge 1) |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | lib.sh, status.sh, session-start.sh, SKILL.md; crew 2.7.0 |
| 100 | Tech Debt | done | none taken |
| 110 | Reflection | done | design rule in crew/CLAUDE.md |

## Problem

Crew was designed as several workers plus one coordinating session. With only one worker, the
coordinator coordinates one session and otherwise sits idle. Blocking a 1-worker crew is wrong:
crew size changes during a run (3 → 1 as workers finish), and the guards (holds, snapshots, git
guard, slots, mail) protect two sessions on one tree just as much as five.

## Decision (the user's, 2026-11-17)

Do not block a 1-worker crew. Let the coordinator work: it may take a task of its own, and should
when the crew has one worker. The worker then acts as a helper: it gets only separate tasks that
can run in parallel, or extra work.

The scripts already allow this (checked): `crew task <ID>` works for the coordinator on itself,
the edit guards apply to it like to a worker, and it is the one who lands. So the change is
guidance plus a hint, not a new mode and no config key.

## Scope

1. `skills/crew/SKILL.md`, Roles → Coordinator: may work on a task of its own (should, with one
   worker); for that task it follows the worker rules (`crew task <ID>`, holds, slots, a copy);
   coordinating comes first (mail, watch wakes, hand-offs interrupt its own work); it gives the
   worker only separate tasks, never part of its own; when it lands its own change nobody else
   looks first — accepted, stated.
2. One line: a short side job goes to a background subagent in the session itself; a worker
   session is worth it for a long job or one the user wants to talk to.
3. `crew status` and the coordinator's SessionStart line: with exactly one worker, a hint to take
   a task itself.
4. Release: version bump, marketplace sync, trigger phrases, README line.

Out of scope: blocking or warning about a 1-worker crew; any change to the guards.

## Acceptance criteria

- The coordinator's status/SessionStart shows the hint when the crew has exactly one worker, and
  not with zero or two+ workers, and never to a worker.
- SKILL.md states the working-coordinator rule (checked by the wording test).
- Both suites (host bash 3.2 and the Docker image) pass.

## Implementation

- `crew/scripts/lib.sh`: `working_note <name>` — a coordinator with no task and exactly one worker is
  told to take a task of its own and give the worker separate parallel tasks. Empty otherwise.
- `crew/scripts/status.sh`: prints it as `you: …` for the caller.
- `crew/hooks/session-start.sh`: prints it as `crew: …` to the coordinator.
- `crew/skills/crew/SKILL.md`: Roles → Coordinator bullet (own task under worker rules, coordinating
  first, separate tasks for the worker, own change landed with no second look, subagent for short side
  jobs); trigger phrases "working coordinator", "coordinator also works", "only one worker", "one helper session".
- Release crew 2.7.0: plugin.json (+ keyword), marketplace.json, root and crew READMEs. No Upgrading
  entry: nothing to do in an existing project.

Verified: `working.test.sh` 13/13; all crew suites ALL GREEN on host bash 3.2 and in the Docker image;
`scripts/check-descriptions.sh` ok.

## Current State

Completed. crew 2.7.0 released.
