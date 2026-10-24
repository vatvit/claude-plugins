---
title: delay — make the timing-based test cases deterministic
status: completed
type: bugfix
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |
| 20 | Requirements | skipped | ACs in the task |
| 30 | Assessment | done | 30-run loop named the flake |
| 40 | POC | skipped |
| 50 | Domain | skipped |
| 60 | Architecture | skipped |
| 70 | Tests | done | 5p/5q, red first |
| 80 | Subtasks | skipped |
| 90 | Implementation | done | delay 2.1.0 (with PLUG-054) |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | see Results |

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

## Results (2026-10-24)

- **The flake, named.** 30 runs of the suite in one `bash:5` container: run 30 failed
  `5m list shows the queued job`, not one of the timing suspects (9f/9g, 10a/10b, 19d–19i were green
  in all 30). Cause: a job id is `<time>-<PID>`, the suite pins the clock (`DELAY_NOW`), and over 30
  runs in one container the PIDs wrapped, so 5j's `add` drew 5a's PID: same id, and `mv` replaced
  5a's queued job, which the test then removed as the nope.sh entry. Not a test-only defect: two
  adds in the same second with a reused PID overwrite a queued job silently.
- **Fix:** `add` never takes an id that a queued job or a result already has; it appends `-2`, `-3`.
- **Test:** 5p/5q force the collision deterministically (`exec` keeps the PID, the clock is pinned):
  red before the fix (the queued job became nope.sh), green after.
- The 2026-10-03 failure was never named, so it cannot be proven to be this one.
- **A second flake, named.** After the fix, 1 of 30 runs failed `4i revoke by ID` and 1 of 60 failed
  `18h approve by ID`. Cause: `find_id` (approve.sh) matched IDs with awk `$1 == id`, which compares
  numerically when both sides look like numbers. A hex ID can: busybox awk reads `75e763` and
  `7e1794` as infinity, so they are equal, and an approve or revoke picked the wrong job or refused.
  About one run in 60 had two such IDs. macOS awk does not do this, so only the container saw it.
  Not test-only: a real registry with two such IDs would revoke or approve the wrong job.
- **Fix:** `($1 "") == id` forces a string compare. **Test:** 18u2/18u3 put two fixed paths whose
  IDs are 75e763 and 7e1794 in the registry and revoke one: red in the container before the fix
  (`[1 1]`), green after; green on the host either way. The trap is now in the root CLAUDE.md awk list.
- 4i and 18h now print the command's own message when they fail, so a future flake names itself.
- **AC3:** after both fixes, 40 of 40 container runs green (4 containers x 10, bash:5), host 259 passed.
