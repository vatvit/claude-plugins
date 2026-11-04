---
title: "crew watch: the coordinator is never woken while its own work sits in the slot queue, and a repeated finding makes --wait unusable"
status: completed
type: bug
priority: high
epic: crew
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | |
| 10 | Requirements | done | |
| 70 | Tests | done | |
| 90 | Implementation | done | |
| 110 | Reflection | done | |

## Problem

A coordinator relies on `watch --wait` in the background to wake it. Seen in one crew over one night and a morning:

1. **A repeated finding makes `--wait` useless.** Two workers each ran a long slot and were rightly silent. `watch --wait`
   exited at once on "W silent 15m while owning … slot #N", the coordinator restarted it, and it exited again within a
   minute on the same finding. So the coordinator stopped running it.
2. **Nothing wakes the coordinator while its own work waits in the queue.** With no watch running, a coordinator's
   background `slot run` that sits in the queue neither fails nor finishes, so nothing fires. One such run waited about
   9 hours overnight, and a gate the next morning waited an hour behind another crew's slots. Each time the user had to
   ask "status?" to wake the coordinator.

PLUG-102 covers a waiter that shows "can start now" and never starts; this task is the coordinator's wake-up.

## Acceptance

- A member that is silent **while it runs its own slot (RUNNING, within estimate)** is not a finding; it becomes one
  once the slot is past its estimate (the existing STALE rule).
- `watch --wait` reports a finding once: the same finding (same member, same subject) does not end a later `--wait`
  until it changes or clears. A test: two `--wait` runs in a row on an unchanged state; the second does not exit on it.
- A new finding: **the caller's own slot waited in the queue over N minutes** (config, default 20), with its ETA and who
  holds the machine, so the coordinator can tell the user.
- `watch --wait --max MIN`: exit 0 after MIN minutes with no finding, a heartbeat for the coordinator to report to the
  user, so a quiet crew still wakes it on a schedule.
- The coordinator role in SKILL.md (or references/watch.md): keep `watch --wait --max 20` running in the background at
  all times while the crew works, and report to the user on every wake where something changed.
- Tests for each; red first.

## Seen again (2026-11-04, a consumer project's coordinator)

Reported by a consumer project's coordinator (crew 2.4.0). No message was lost: `crew inbox --all` showed nothing
unread, and every worker SendMessage arrived. What went wrong was a stall that nothing reported. From ~01:00 to ~09:50 every
session of that crew sat idle (crew time since 00:00: 36:31 idle against 8:41 counted). All 7 of its slots waited
behind another crew's exclusive slot stuck at "can start now" (PLUG-102). Nothing woke the coordinator, so the user
found the stall by asking ("so, nothing done >6h?" the day before, and "Seems like some updates missed").

Two causes this task does not yet cover:

- **Nothing restarts `watch --wait` after a compaction or a session start.** The coordinator's watch was not running:
  it had not been restarted after a compaction. Wanted: the crew SessionStart hook (hooks/session-start.sh) tells a
  coordinator "watch is not running — start `watch --wait --max 20` in the background" when it finds none.
  **Split out to PLUG-105** (disjoint files, can run alongside this task).
- **The time-review finding repeats too.** Started at 11:16, `watch --wait` exited at once on "this crew waited 315m in
  the slot queue since the last review — next: run crew time…", and kept doing so until `crew time` ran (which took
  >120 s). This is the same repeated-finding defect as point 1 above, from the PLUG-098 review trigger. The
  "reports a finding once" rule must cover it.

## The members' side (2026-11-04, a second consumer project's coordinator)

The coordinator also misses events from its **workers**: they go quiet without saying why, and nothing tells the
coordinator what they wait for. Seen over one night and one morning (counts only):

- Workers were "silent 58–63 min while owning a slot". Each was waiting in the queue or running past its estimate,
  but sent nothing. The coordinator could not tell a worker waiting on the machine from one that was stuck or gone,
  short of asking each one.
- A worker's own run went past its estimate (20 min booked, 60+ min used) with no word until the coordinator asked;
  the coordinator's gate waited behind it.
- A worker that finished its turn and went idle (waiting on its own background job) produced no crew event; only
  Claude Code's one-shot idle notice, which the coordinator must subscribe to per member and per wait.

Stays in this task (watch's finding logic), extending the first Acceptance item from "running its own slot" to
"waiting":
- A member waiting on the queue or on its own background run counts as **waiting, not silent**: `watch` shows
  "W2 waiting: slot #N, queued 40 min, ETA 12:10" and makes it a finding only at the STALE rule.
- Tests on a generated slot log and sessions; red first.

**Split out to PLUG-107** (slot.sh and status, can run alongside this task): `slot run`/`slot start` posts mail to
the coordinator when a member's slot starts after a long wait or runs past its estimate, and `crew status` shows each
member's current wait.

## Implementation (2026-11-04)

`watch_waits`: a member waiting in the queue or running its own slot within the estimate is not `silent`; `status` shows the wait. New `queue:<id>` finding past `slotWaitMin` (20) with ETA and what is ahead. `--wait` keeps its memory in `$STATE/watch.reported` (outlives the run, drops cleared keys), so the same finding (including `review:time`) wakes it once. `--max MIN` exits 0 with `watch: no new finding for MINm; open: N`. SKILL.md: the coordinator keeps `watch --wait --max 20` running and restarts it after every wake and compaction.

Tests: watch.test.sh: waiting/running slot not silent; status shows the wait; queue finding at 21m; a second `--wait` does not exit on the same finding; `--max 0` heartbeat with `open: 1`; a cleared finding fires again.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
