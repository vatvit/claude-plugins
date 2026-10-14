---
title: delay — report a non-zero exit as "the job ran, the script failed", not as a delay fault
status: completed
type: improvement
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | job 20261013-214216-79740 ran fine, exit 1 from 15 red e2e; user + Claude misread `failed` |
| 20 | Requirements | done | acceptance criteria below, agreed 2026-10-14 |
| 30 | Assessment | done | delay.sh list/show only; dispatch and meta untouched |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | ran / not run split already in the status set |
| 60 | Architecture | done | one `outcome` helper in delay.sh |
| 70 | Tests | done | 7c 7d 9i 9j 11e red before; 11f 11g guard a running job |
| 80 | Subtasks | skipped | one small change |
| 90 | Implementation | done | 242/242 host + bash:5; mutation turns the 5 red |
| 100 | Tech Debt | done | none taken |
| 110 | Reflection | done | SKILL.md result table gains the reporting rule |

## Description

The project-c night gate (job `20261013-214216-79740`, 2026-10-14) ran exactly as approved and
exited 1 because 15 e2e tests were red. `list` showed `failed`, and both the user and Claude
first read that as "the delay job failed" — a plugin fault. The status set already separates the
two (`not-approved`, `docker-unavailable`, `needs-reapproval`, … mean delay did not run it), but
the bare word `failed` hides that.

## Acceptance criteria

- `list` and `show` say whether the job **ran** and, if so, the script's exit code — a non-zero
  exit reads as the script's verdict, not as a delay failure; statuses where nothing ran say so.
- One helper in `lib.sh` produces that wording; `list` and `show` both use it.
- The stored `status=` value in `meta` is unchanged (no migration, old results still display).
- SKILL.md tells Claude to report `failed` as "ran; the script/tests failed (exit N)".
- Suite passes on host bash 3.2 and bash:5; new checks seen red by reverting the change.

## Implementation (2026-10-14)

- `delay/scripts/delay.sh`: `outcome <status> <exit>` — `ran, exit 0 — passed`,
  `ran, exit N — the script failed`, `ran, killed at the timeout`, `queued` / `running`, else
  `not run — <status>`. `list` prints it as the last column (time moved before it); `show` adds an
  `outcome=` line. Stored `status=` unchanged.
- Deviation from the criteria: the helper lives in `delay.sh`, not `lib.sh` — `list` and `show`
  are its only consumers, both in that file, so it is still one source.
- `show` on a result without `meta` (still running) says `outcome=running`, not `not run` — caught
  while writing it, covered by 11f/11g.
- SKILL.md: report `failed` as "the job ran; the tests failed (exit N)". README `show` line. 2.0.0 -> 2.0.1
  (wording only), plugin.json + marketplace synced.

## Current State

Completed, not committed. Suite 242/242 on host bash 3.2 and bash:5. Real project-c result now
reads `ran, exit 1 — the script failed`.
