---
title: crew copy test flake — "remove after apply" failed once under load
status: blocked
type: bug
priority: low
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

During PLUG-085 (2026-10-24), the crew host suite failed once in copy.test.sh, "-- remove (PLUG-065)":
`remove after apply` (rc 1), `…the folder is gone`, `…and git forgot the worktree`. It ran while three
other suites (crew in a container, kickoff on host and in a container) ran at the same time. Not
reproduced since: copy.test.sh alone 5/5, six copies at once 6/6, the full host + container crew
suites together twice. `copy_remove` does not use the comparisons PLUG-085 changed.

Candidates: `git worktree remove --force` failing under load, or `copy_unlanded` seeing a difference
right after `apply`. The check now prints `copy remove`'s own message when it fails, so the next
failure names its cause.

## Acceptance criteria

1. The cause is named from a failure's message (or a deterministic reproduction).
2. A test forces it, red before the fix, green after.
3. The crew suite passes 30 consecutive runs under load (host and container in parallel).

## Current State (2026-10-24) — blocked until it recurs

- Not reproduced in 40 runs: host copy.test alone 5/5, six at once 6/6, full host + container suites
  together 2/2, copy.test in a container capped at 0.5 CPU 20/20 (repo mounted read-only). A heavier
  host load loop was declined: too much load on a shared machine.
- Host-only suspects remain (macOS git, file timing under /var/folders): each suite already has its
  own HOME, CREW_HOME and repo, so no real crew state is shared.
- copy.test.sh now prints, on failure of "remove after apply", remove's message plus the output of
  the `release a.txt --unchanged` and `apply one` before it (both were discarded).
- **Next:** when it fails again in any normal run, read that message, write the failing test, fix.
  AC3 ("30 runs under load") to be revisited then: a capped container is the safe form of it.
