---
title: "crew slots: a member's slot wait and overrun reach the coordinator as mail, and crew status shows what each member waits on"
status: completed
type: feature
priority: high
epic: crew
created: 2026-11-04 11:54
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | |
| 10 | Requirements | done | |
| 30 | Assessment | done | |
| 70 | Tests | done | red first, on a generated slot log and sessions |
| 90 | Implementation | done | |
| 100 | Tech Debt | done | |
| 110 | Reflection | done | |

## Problem

The coordinator misses events from its **workers**: they go quiet without saying why, and nothing tells the coordinator
what they are waiting on. Seen in a consumer project (crew 2.4.0) over one night and one morning, 2026-11-03/04; first
reported in PLUG-103 §The members' side:

- Workers were "silent 58–63 min while owning a slot". Each was waiting in the queue or running past its estimate,
  but sent nothing. The coordinator could not tell a worker waiting on the machine from one that was stuck or gone,
  short of asking each one.
- A worker's own run went past its estimate (20 min booked, 60+ min used) with no word until the coordinator asked;
  the coordinator's gate waited behind it.
- A worker that finished its turn and went idle (waiting on its own background job) produced no crew event. The only
  signal was Claude Code's one-shot idle notice, which the coordinator must subscribe to per member and per wait.

## Scope

- `slot run` (and `slot start`) posts to the coordinator's mailbox when a member's slot **starts after waiting over N
  minutes**, and when it **runs past its estimate** (once, with the new ETA). Then `watch --wait` wakes on mail, not on
  a guess about silence.
- `crew status` shows each member's current wait (queue, own run, a peer, the coordinator, the user) in one column.
- Not here: watch treating a waiting member as waiting rather than silent. That is PLUG-103's finding logic.

## Acceptance

- Red first: a member slot that waited > N min and then starts → one mail to the coordinator; a slot past its estimate
  → exactly one mail with the new ETA; the coordinator's own slots post nothing to itself.
- `crew status` shows the wait column for a queued, a running and an idle member.
- Host and container suites green.

## Origin

Split out of PLUG-103 so the slot/status side can run alongside watch's finding logic (disjoint files: slot.sh and
status vs watch).

## Implementation (2026-11-04)

`slot_started` (run and manual start): a member's slot that waited past `slotWaitMin` mails the coordinator (`SLOT — #N started after Wm waiting`). `slot run` starts `_slot_overrun` in the background (fds closed, killed after the run and via CREW_ON_EXIT, sleeps in ≤5 s steps): one mail once past the estimate if still running. The coordinator's own slots mail nobody. `crew status` activity line shows each member's slot wait (waits on a peer or the user are not observable and are not shown).

Tests: queue.test.sh §PLUG-107: wait mail at 25m, none for the coordinator's own wait, one overrun mail, none within the estimate, none for a quick start.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
