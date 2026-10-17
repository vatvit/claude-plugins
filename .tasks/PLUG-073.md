---
title: crew — solo and multi-repo field feedback
status: completed
type: epic
epic-name: crew-solo
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | per sub-task |
| 30 | Assessment | done |  |
| 40 | POC | skipped |  |
| 50 | Domain | skipped |  |
| 60 | Architecture | done | per sub-task |
| 70 | Tests | done | per sub-task |
| 80 | Subtasks | done | PLUG-074..076, created at proposal |
| 90 | Implementation | done | crew 2.2.0 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | CLAUDE.md files reviewed for duplication |

## Goal

Make crew fit the whole life of a crew — including its end — and a Mac that runs crews in more than one
repo at once.

## Why

Field feedback, 2026-10-17. A project closed its crew and went solo, while a session in a second repo on
the same Mac stayed live. Three gaps showed:

1. Slots are per repo (`<git-common-dir>/crew`), but CPU is per machine. Heavy runs in two repos could not
   queue against each other; the sessions fell back to hand-sent "clear" messages.
2. There is no way to end a crew. `whoami --leave` is per session; a crew "ends" only by its sessions
   closing, leaving holds, slots, registry names and the crew directory behind.
3. There is no scriptable "is a crew running here?" probe, and no documented pattern for project rules
   that apply only while a crew runs. The project hand-split its CLAUDE.md into "always" and "crew only".

## Scope

- PLUG-074: machine-wide slot queue across repos
- PLUG-075: `crew end` — disband a crew, back to the no-crew state
- PLUG-076: `crew active` probe, and the solo / per-mode project rules guide

The three are independent and can run in parallel sessions. PLUG-075 and PLUG-076 both edit the skill and
README; PLUG-074 touches `slot.sh` and `lib.sh`. Check crew holds before starting.

## Success Criteria

- Each sub-task's acceptance criteria met, suites green on host and `bash:5`, and from a copy of `crew/`
  alone.
- One version bump at the end, with `plugin.json`, `marketplace.json`, `SKILL.md` and the root README in
  sync (repo CLAUDE.md, "Changing an Existing Plugin").

## Sub-tasks

- PLUG-074: crew — machine-wide slots: a heavy run in one repo queues against another repo's
- PLUG-075: crew — `crew end`: disband a crew and return the repo to the no-crew state
- PLUG-076: crew — `crew active` probe, and the guide for working solo and per-mode project rules

## Outcome (2026-10-17)

All three sub-tasks shipped as crew 2.2.0 (one bump): `plugin.json`, `marketplace.json`, SKILL.md
triggers and pointer table, crew README, and the root README crew section in sync. The CLAUDE.md files
were reviewed for duplication and conflicts: crew/CLAUDE.md now points to the root file for the
guard-hook exception instead of restating it, and records the machine-wide slots, `crew end` and
`crewRules`. The root CLAUDE.md names crew's home as machine-wide state, adds crew's new trigger words,
and states the `init` rule as PLUG-070 decided (no bare *init* trigger; a namespaced argument is fine).
adopt.md no longer keeps its own stale copy of the project-only key list.

## Current State

Completed. Nothing committed yet: awaiting the user's commit/push approval.
