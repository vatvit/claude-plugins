---
title: crew status shows which task each session works on; a second session on the same task gets a note
status: proposed
type: improvement
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

## Description

Follow-up to PLUG-060, which made "one task, one session" a stated crew rule (wording only).
Nothing in crew links a session to its task yet: a task id is only a label on a hold
(`hold --task`) and a hand-off (`msg handoff --task`). This task makes the rule visible:

- `crew status` shows each session's task;
- a session that takes up a task another live session already owns gets a note naming the owner.

This needs new state (session → task), how it is set and cleared, and tests. That is why it was
split out of PLUG-060.

## Open questions

- How a session declares its task: `whoami --task`, a new `crew task <ID>`, or inferred from
  `hold --task` / `msg handoff --task`.
- A note or a denial when a second session takes the same task (crew denies only for git and holds today).

## Current State

Proposed. Nothing changed.
