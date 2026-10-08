---
title: delay — verify wake from real sleep on hardware
status: proposed
type: research
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

Follow-up from PLUG-013. Three night runs proved everything except **waking from real sleep**
(pmset dark wake → launchd's overdue StartInterval tick → the job runs). On Vat's setup the Mac
never slept: `displaysleep 0`, an external display (lid close → clamshell, not sleep), and
Claude sessions' `caffeinate` holds. Vat chose (2026-10-08) to assume it works and check later.

## How to check (~15 min, daytime)

1. `sudo ".../approve.sh" --window <now+5min> 1`
2. `delay.sh add smoke`, then `sudo ".../start.sh" --no-awake`
3. Apple menu → Sleep (forces sleep despite idle blockers); don't touch it until a few minutes
   past the window start.
4. Check: `delay.sh list` (passed, `started` near the window start); `pmset -g log` shows
   Sleep → Wake/DarkWake; runner unloaded; `/tmp/claude-delay-runner.$USER.err` empty.
5. Restore: `--window 03:00 4`.

If it fails: the dark wake is too short for launchd's tick. Candidate fix: `start.sh` (root)
schedules the wake, and the runner takes a short `caffeinate -i -t 120` on any tick inside the
window before checking docker.

## Acceptance criteria

1. The smoke job runs within ~1 min of the window start while the Mac was asleep.
2. The power log shows a real sleep before it and a wake at window start + 30 s.
