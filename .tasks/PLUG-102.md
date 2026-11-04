---
title: "crew slots: a live `slot run` waiter shows \"can start now\" for 15+ minutes and never starts (crew 2.4.0)"
status: completed
type: bug
priority: high
epic: crew
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | slot.sh run's wait loop vs `slot list`'s "can start now" |
| 70 | Tests | done | red first: a waiter whose slot list says it can start does start |
| 90 | Implementation | done | |
| 110 | Reflection | done | |

## Problem

Seen twice on one machine with two crews sharing the slot queue (2026-11-03 and 2026-11-04):

1. 12:39–19:56: a waiter started under crew 2.3.1 kept waiting after 2.4.0 was installed. `slot list` said "can start now" for hours. Killing the waiter and requeuing fixed it.
2. 2026-11-04 00:45–01:01+: an exclusive slot (8 m) said "waiting · can start now". Its waiter process was alive: `slot.sh run exclusive 8 …`, crew **2.4.0**, started 00:50:53, from a second Claude config dir (`~/.claude-z3k/plugins/cache/…/crew/2.4.0`). No slot was running, and memory was 0 of the 22 GB budget. Every slot of both crews queued behind it.

So "can start now" in `slot list` and the waiter's own start check disagree. Case 2 is not a version mismatch. A plugin cache under a different config dir is the one difference visible from outside: a different state path, or a different user config such as `slotMemGB`?

## Acceptance

- `slot list` and the waiter use one function to decide "can start".
- A waiter that cannot start says why in `slot list`.
- `watch` flags a slot shown "can start now" for more than N minutes.

## Seen again (2026-11-04 09:50)
The other crew's exclusive was still "can start now" about 9 hours later, and it held every slot of this crew all night. The user allowed passing it. The plugin has no way to skip another crew's dead slot: `slot release` covers only this crew's slots. The workaround is to rebook this crew's slots with `--prio critical`. Wanted: a stale *waiting* slot ("can start now" for N minutes with no start) gets reaped or passed, like a stale running slot is flagged.

## Implementation (2026-11-04)

Root cause: `_slots_no_pass` and `slots_plan` read `cfg slotMemGB`, which is per account, so two accounts' waiters computed different orders and each saw the other's slot first (the second account's waiter, ~/.claude-z3k). Fix: each row carries its requester's budget (field 13); `slots_budget` = max over the queue; the plan reads only the queue. Backstop: the waiter leaves its reason in `$CREW_HOME/slots.wait` on every poll (`_slot_wait_note`); a startable slot is `stuck` (plan field 18/19) when that note is newer than the last `slots.log` event, or when no event happened for `slotStuckMin` (10). A stuck slot keeps go=1 for its owner and holds nobody back; `slot list` shows `STUCK (…)`, `watch` reports `stuck:<id>` for any crew. `_start` computes the plan once instead of three times.

Tests: queue.test.sh §PLUG-102: two crews with different user budgets get one order and the over-budget start is refused; a disagreeing waiter note makes the slot behind it start at once; no event for 11m makes it pass; the owner can still start a stuck slot; the waiter note appears while waiting and is gone after the run.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
