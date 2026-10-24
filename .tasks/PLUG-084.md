---
title: crew — the pre-bash hook parks a session id for a whoami that is not a join
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

Found during the PLUG-040 live check (crew 2.2.0). `hooks/pre-bash.sh` parks the session id under
the word after `whoami ` for any command line containing `crew.sh … whoami`. A bare `whoami 2>&1`
parked it as `crew-pending/2`, and `whoami --leave <name>` as `crew-pending/leave`. Neither is a
join. The files stay, so a later `whoami 2` / `whoami leave` without `--sid` would bind to the wrong
session id.

## Acceptance criteria

1. Only a join parks an id: `whoami <name> …`. Not a bare `whoami`, not `whoami --leave`/any
   option, not a redirection or operator (`2>&1`, `;`, `|`) taken as the name.
2. Regression cases in the hook tests, red before the fix; host + `crew-test`.

## Current State

Proposed. The two stray files from the live check were removed by hand.
