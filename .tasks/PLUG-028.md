---
title: crew — slot queue for machine time (cpu / exclusive / quiet)
status: proposed
type: feature
epic: crew
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

A single queue for machine time (playbook §5, §9.1, §9.2), enforced by a script instead of by
people remembering to check.

- `slot.sh request <name> <cpu|exclusive|quiet> <minutes> [--why text] [--prio failing|critical]`,
  `start`, `done`, `list`, `cancel`, and `wait <class>` (blocks until a slot is open; for
  background jobs and automatic retries).
- Rules: *cpu* runs alongside other *cpu*. *exclusive* is one at a time with nothing else
  inside it (e.g. a browser e2e run). *quiet* runs alone (timing measurements). Order: work
  failing on the shared branch first, then the user's critical asks, then shortest first.
- A slot past its estimate by a set grace period is reported as stale and is never killed
  silently. The Coordinator can `release` it.
- A `status.d` part (queue + ETA per session), and a `msg.d` kind `queue-moved` that gives
  every waiting session its new time and the reason.
- `references/slots.md`, including how a project wraps its own heavy commands
  (`slot.sh wait exclusive && run-e2e`).

## Acceptance criteria

- [ ] Two *exclusive* requests never run together. A *cpu* request is refused while an
      *exclusive* slot is running.
- [ ] A *quiet* slot starts only when nothing else is running, and blocks new starts while
      it runs.
- [ ] Priority order and shortest-first hold on a mixed queue.
- [ ] `wait` returns once the slot opens. A stale slot shows in `list` / `status`.
- [ ] `msg.sh queue-moved` lists each waiting session with its new ETA.
- [ ] The suite passes in docker and from a standalone copy.

## Notes

Separate from `delay`, which runs approved jobs later in the user's run window. This slice is
"now, in turn". Keep the vocabulary disjoint: *slot*, never *job*.
