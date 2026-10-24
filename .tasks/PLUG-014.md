---
title: delay — verify wake from real sleep on hardware
status: completed
type: research
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-013 night runs |
| 20 | Requirements | skipped | ACs in the task |
| 30 | Assessment | done | first attempt only dark-woke, see Results |
| 40 | POC | done | live check 2026-10-24 |
| 50 | Domain | skipped | |
| 60 | Architecture | skipped | |
| 70 | Tests | skipped | hardware check, not automatable (delay/CLAUDE.md § Testing) |
| 80 | Subtasks | skipped | |
| 90 | Implementation | skipped | no fix needed |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | delay/CLAUDE.md § Testing |

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

## Results (2026-10-24, delay 2.1.0)

Both ACs pass. Window 15:20 for 3h (other queued jobs ran in it too), `start.sh --no-awake`.
- **First attempt failed to sleep, not to wake.** On mains power, Apple menu → Sleep only reached
  DarkWake (`Entering DarkWake state due to 'Software Sleep' … Using AC`) and a second of HID
  activity made it a full wake. Cause: processes holding *PreventSystemSleep* (`caffeinate -s`, two of
  them stale for over two weeks), which on AC turns even a menu sleep into a dark wake. On battery
  that assertion does not apply.
- **On battery:** `15:12:40 Entering Sleep state … Using Batt` (a real sleep); the power log listed
  `UserWake wakeAt=15:20:30 info="claude-delay"`; `15:20:31 Wake from Deep Idle … rtc` (window start
  + 31 s, a full wake, not a dark wake); the smoke job `started=15:21:19` (48 s later: launchd's
  overdue tick), `finished=15:21:42`, exit 0, before anyone touched the Mac.
- The candidate fix (`caffeinate -t 120` on a tick) is not needed: a `pmset schedule wake` is a full
  wake, and the runner's own hold keeps it up while jobs run.
- Lesson for the docs: a Mac on AC with any `caffeinate -s` holder never really sleeps, so the wake is
  moot there; the wake path matters on battery or with no such holder.
