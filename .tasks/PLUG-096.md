---
title: "crew slots: back-to-back cpu slots starve a waiting exclusive slot"
status: completed
type: bug
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | cause found in slots_sorted: shortest-first ordering, not the start path or the cross-crew read |
| 10 | Requirements | done | rule kept from slots.md; failing/critical cpu may still pass |
| 70 | Tests | done | slots.test.sh +6, crosscrew.test.sh +1, red first |
| 90 | Implementation | done | `_slots_no_pass` in slot.sh |
| 110 | Reflection | done | slots.md, playbook.md |

## Problem

slots.md says: "A `cpu` slot never jumps ahead of a waiting `exclusive` or `quiet` slot." Observed on one machine with
two crews from different repos: an exclusive slot (60 min) requested at 09:03 waited until past 10:20 without starting.
In that time, cpu slots from the other crew started back to back, one after another. The ETA of the exclusive slot
moved forward every time a new cpu slot started.

## Acceptance

- Reproduce in a test first: an exclusive slot waiting while cpu slots run, and a new cpu slot requested after the
  exclusive one must not start before it (across crews too).
- Running cpu slots finish; no new cpu slot starts while an exclusive one waits.
- A mutant that lets cpu jump ahead goes red.

## Notes

- Check whether the starts came from `slot run` or `slot request` + `slot start`, and whether a cross-crew queue
  read is involved.

## Evidence (2026-11-02)

The exclusive slot #3037 waited from 09:03 to 10:20. Over that time, these cpu slots started ahead of it: #3040 (09:11, the other crew), #3041 and #3042 (~09:12, the same crew as #3037), and #3072 (10:18, the other crew). So it is not a cross-crew issue only. When it was re-requested with `--prio critical` (#3073), it started at once, because no cpu slot was running at that moment.

## Implementation (2026-11-03)

**Cause.** Neither `slot run` vs `request`/`start` nor the cross-crew read: the queue order itself. Waiting slots
sort by prio, then **shortest**, then first come, and `slots_plan` lets a `cpu` slot start beside running `cpu`
slots as long as no `exclusive` sorts ahead of it. A 5-minute `cpu` slot requested after a 60-minute `exclusive`
sorted ahead of it, so it started beside the running ones; by the time it ended another had come. That matches the
evidence (both crews' cpu slots passed #3037, and `--prio critical` went straight in). The old test
"shortest-first: cpu 3m went ahead of exclusive 5m" asserted exactly this behaviour.

**Fix.** `slots_sorted` pipes the waiting slots through `_slots_no_pass`: a `cpu` slot that sorts ahead of a waiting
`exclusive`/`quiet` slot requested before it (prio no worse; ties by id) moves to just behind the last such slot.
`exclusive`/`quiet` keep shortest-first among themselves, and `slots_plan` then blocks the moved `cpu` slot and
gives it an ETA after the exclusive one. A `cpu` slot with a better prio (failing, critical) still goes first.

**Tests.** slots.test.sh: the old shortest-first check now asserts the opposite, and a new block reproduces the
report (cpu running, exclusive 60 waiting, a later cpu 5 neither starts beside it nor once the machine is free;
a failing-prio cpu still goes first). crosscrew.test.sh: a later cpu slot of another crew waits behind alpha's
exclusive. Seen red first (4 fails before the fix), and with `_slots_no_pass` removed after it: slots 8 fails,
crosscrew 1. Host and container green (slots 39, crosscrew 27).

**Not covered.** Shortest-first can still keep a long `exclusive` behind a stream of *shorter exclusive* slots
requested later. Not seen in practice; no aging rule added.

