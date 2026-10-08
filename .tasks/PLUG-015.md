---
title: delay — make the timing-based test cases deterministic
status: proposed
type: bugfix
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

Follow-up from PLUG-013. `delay/scripts/test/delay.test.sh` failed once in 11 container runs
(2026-10-03) and could not be reproduced in 8 reruns, so the failing check was never named.
Suspects are the cases that depend on wall-clock timing or background processes:
- 9f/9g (timeout: `FAKE_SLEEP=6`, a 1 s timeout, kill/wait)
- 10a/10b (a live lock holder via `sleep 30 &`)
- 19d–19i (the awake hold: the shim's background `sleep 60`, kill -0 checks)

## Acceptance criteria

1. Run the suite in bash:5 in a loop (e.g. 30×), with failing check names logged; identify the flake.
2. Replace the timing dependence (e.g. poll for a state instead of a fixed sleep).
3. 30 consecutive green container runs.
