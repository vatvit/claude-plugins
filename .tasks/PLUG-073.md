---
title: crew — solo and multi-repo field feedback
status: proposed
type: epic
epic-name: crew-solo
priority: medium
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

## Current State

Proposed 2026-10-17 from a peer session's field report. Not started. Nothing waits on it.
