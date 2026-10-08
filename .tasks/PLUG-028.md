---
title: crew — slot queue for machine time (cpu / exclusive / quiet)
status: completed
type: feature
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | same session; PLUG-026 Architecture applies; `delay` is "later", this is "now, in turn" |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | with_lock's per-call EXIT trap would clobber `slot run`'s cleanup → one lib-owned trap |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `crew/scripts/test/slots.test.sh` (32 checks) |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 129/129 host + docker |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | references/slots.md, SKILL/README rows, crew CLAUDE.md trap rule; 0.4.0 |

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

## Architecture

- `crew/scripts/slot.sh`, dual-use. Queue file `<state>/slots` TSV (id, name, class, minutes, prio,
  requested, state, started, why); ids from `slots.seq`.
- `slots_plan` (awk) simulates the queue once: it gives each slot an ETA, an end and "startable
  now". A cpu slot starts when no exclusive or quiet slot is running or waiting ahead of it. An
  exclusive or quiet slot starts when nothing is running and nothing is waiting ahead of it.
  `start` is refused unless the plan says the slot can start.
- `slot run … -- cmd` = request + poll (`CREW_SLOT_POLL`, default 5 s) + run + done, with the
  release in `CREW_ON_EXIT` so a killed command still frees the slot.
- `slot_quiet_holder` exported for the git guard (PLUG-031 holds pushes during another's quiet slot).
- Decision: the queue never starts or kills anything by itself. Stale is only flagged, and the
  coordinator `release`s.

## Implementation

`slot.sh`, `status.d/slots.sh`, `msg.d/slots.sh` (`queue-moved`, `slot`), lib: single EXIT trap
(`crew_on_exit`, `CREW_ON_EXIT`); `slots.test.sh` 32/32; full run 129/129 host + `crew-test`.

## Reflection

- The `crew/CLAUDE.md` design rules now say that lib owns the EXIT trap.
- Lesson: shortest-first ordering means a short cpu request legitimately overtakes a longer
  waiting exclusive one. My first test assumed it would not, and the test was wrong, not the
  queue.

## Current State

Completed. Build green.
