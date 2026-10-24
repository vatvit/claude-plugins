---
title: crew copy test flake — "remove after apply" failed once under load
status: proposed
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
