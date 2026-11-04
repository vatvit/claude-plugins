---
title: "crew slots: a later, shorter exclusive slot passes a waiting exclusive slot — seen in practice"
status: completed
type: bug
priority: medium
epic: crew
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | |
| 10 | Requirements | done | |
| 30 | Assessment | done | |
| 70 | Tests | done | red first: the case below |
| 90 | Implementation | done | |
| 100 | Tech Debt | done | |
| 110 | Reflection | done | |

## Summary

PLUG-096 left one case open: "Shortest-first can still keep a long `exclusive` behind a stream of *shorter exclusive*
slots requested later. Not seen in practice; no aging rule added." PLUG-090's no-pass rule blocks cpu vs
exclusive/quiet, memory and group competition, but not exclusive vs exclusive.

It has now been seen, in a consumer project, 2026-11-03. A 50-min `exclusive` slot (a review run the user was
waiting for) was waiting with an ETA of 18:23. A worker's later 40-min `exclusive` request went ahead of it and pushed it
to 18:48. A second later request did the same. Earlier the same day the long slot had already slipped from ~14:36 to
~18:23 as shorter ones kept arriving. The worker had to cancel its own requests and script a waiter that only requests
once the long slot leaves the queue — a workaround each session must remember.

## Scope

- A waiting `exclusive`/`quiet` slot is not passed by a later-requested `exclusive`/`quiet` slot of no better prio
  (extend `_slots_no_pass`'s "compete" set), or add ageing so a waiting slot's priority rises with its wait. Decide
  which in Requirements; the simplest that stops unbounded overtaking wins.
- `--prio failing` / `critical` still go first.
- Document the rule in references/slots.md §Order.

## Acceptance

- Red first: slot A exclusive 50 requested at t0, slot B exclusive 40 requested at t1 > t0 → today B goes before A;
  after the fix A goes first (or, with ageing, A's start is bounded).
- Existing slot tests stay green, host and container.

## Origin

Seen by a crew coordinator and worker in a consumer project; follows PLUG-096's "Not covered" note and PLUG-090.

## Checked against crew 2.4.0 (2026-11-03 17:1x)

Still open. `_slots_no_pass`'s `blocks(j, i)` in scripts/slot.sh returns true only for `c[i] == "cpu" && c[j] != "cpu"`,
both-declare-memory under a budget, or a shared group. A waiting `exclusive` j and a later `exclusive` i match none of
these, so shortest-first still lets i pass j. slots.md §Order lists the same three competing pairs. The fix may be one
more clause: `(c[i] != "cpu" && c[j] != "cpu")`.

## Seen again (2026-11-03 22:50)

Exclusive #3894 (45 m, requested after #3893) is queued with ETA 22:50, ahead of exclusive #3893 (50 m, ETA 23:35). Both wait on a cpu slot running 84 min past its 20 m booking, so the later, shorter slot goes first when it ends.

## Implementation (2026-11-04)

`_slots_no_pass`: `blocks(j,i)` is now `c[j] != "cpu" || …`, so nothing passes an earlier exclusive/quiet slot of no lower priority (the cpu clause and the new exclusive clause in one).

Tests: queue.test.sh §PLUG-101: a later, shorter exclusive (40m) waits behind an earlier one (50m); `--prio critical` still goes first.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
