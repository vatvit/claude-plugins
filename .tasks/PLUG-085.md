---
title: awk compares IDs and names as numbers when they look numeric (crew, kickoff, docs-manager)
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

PLUG-015 found that awk `$1 == id` compares numerically when both sides look like numbers:
busybox reads hex `75e763` and `7e1794` as infinity, so they are equal (delay fixed with
`($1 "") == id`; the trap is in the root CLAUDE.md awk list). The same `$N == var` pattern
appears in other plugins, e.g. crew `snapshot.sh`, `slot.sh`, `msg.d/slots.sh`, `msg.d/holds.sh`,
`watch.sh`, `lib.sh`; kickoff `ports.sh`, `inspect.sh`; docs-manager `survey.sh`, `external.sh`.
Most compare names, paths or integers, where it is at worst an edge case (a session name `1e5`
equal to `100000`), but each needs a look.

## Acceptance criteria

1. Every `$N == var` awk comparison of an id, name or path in crew, kickoff and docs-manager is
   either a forced string compare or noted as numeric on purpose (e.g. integer slot ids).
2. Where a real collision is possible, a test shows it (red in the container before the fix).
3. Each plugin's suite is green on the host and in the container.
