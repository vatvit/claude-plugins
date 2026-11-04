---
title: "crew: a coordinator whose watch is not running is told so at session start, resume and compact"
status: completed
type: bug
priority: high
epic: crew
created: 2026-11-04 11:48
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | |
| 10 | Requirements | done | |
| 30 | Assessment | done | |
| 70 | Tests | done | red first |
| 90 | Implementation | done | |
| 100 | Tech Debt | done | |
| 110 | Reflection | done | |

## Problem

The coordinator depends on `watch --wait`, run in the background, to wake it. Nothing starts it or reminds the
coordinator about it. After a compaction a coordinator in a consumer project (crew 2.4.0, 2026-11-04) did not restart it,
and its crew then stalled for ~9 h overnight with nobody told (details: PLUG-103 §Seen again). hooks/session-start.sh
already has a coordinator branch (`git_policy_note`, `tree_policy_note`, `watch_stamp`) but says nothing about watch.

## Scope

- `watch --wait` leaves a liveness mark (pid or heartbeat file in the crew state) while it runs, and clears it on exit.
- session-start.sh: for a coordinator with no live watch, print one line: watch is not running, start
  `watch --wait --max 20` in the background (`--max` comes from PLUG-103; until it lands, plain `--wait`).
- It fires on startup, resume and compact. A dead pid (killed session) counts as not running.
- Workers get nothing new.

## Acceptance

- Red first: coordinator, no watch → the line is printed; live watch → no line; stale mark with a dead pid → the line is printed.
- The hook still exits 0 and stays within its 5 s timeout.
- Host and container suites green.

## Origin

Split out of PLUG-103 so it can run alongside it: it touches hooks/session-start.sh and the watch liveness mark,
while PLUG-103 touches watch's finding logic.

## Implementation (2026-11-04)

A loop or `--wait` watch writes `$STATE/watch.pid` and removes its own on exit; `watch_running` (pid file + `kill -0`); `watch_off_note` is the one test, used by session-start.sh (start, resume, compact) and status.d/watch.sh for the coordinator.

Tests: watch.test.sh §PLUG-105: told with no watch, silent with a live pid, told again with a dead pid, workers never told, status tells the coordinator, a loop leaves no pid file, a running watch is seen.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
