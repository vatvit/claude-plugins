---
title: "crew slots: a project can ignore another crew's slots by name"
status: completed
type: feature
priority: medium
epic: crew
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | slot.sh slots_plan / _slots_no_pass; PLUG-074 (one queue per machine) |
| 30 | Assessment | done | |
| 70 | Tests | done | red first in scripts/test (crosscrew.test.sh) |
| 90 | Implementation | done | |
| 100 | Tech Debt | done | |
| 110 | Reflection | done | |


## Problem

Two crews share one machine queue. One of them runs light tests, and its user decided that it ignores the other
crews' slots. The other crew still waits behind that crew's exclusive slots, whether they are running or waiting. On
2026-11-04 it lost a night to one of them (see PLUG-102). The user said that project "requires not many resources", so
the others can ignore its locks. Today the only workaround is `--prio critical`, which passes a waiting slot but not a
running one. Running a command outside the queue loses this crew's own ordering and memory budget.

## Scope

- A per-project config key (e.g. `slotIgnoreCrews`: a list of crew names). Their slots don't block this crew's slots
  anywhere in the plan: not in `_slots_no_pass`, and not in `slots_plan`'s running exclusive, cpu, memory or group checks.
- The ignored crew's slots still show in `slot list`, marked "ignored".
- This crew's own queue, memory budget and groups work as before.
- Set only on the user's word, like `committer`/`push`.

## Implementation (2026-11-04)

New project-only array key `slotIgnoreCrews`; `slots_ignored` (never this crew's own id). Rows of an ignored crew block nothing in `_slots_no_pass` or `slots_plan` (running or waiting) and show `· ignored` in `slot list`. The other crew still waits for ours, so no deadlock. Docs: set only on the user's word.

Tests: queue.test.sh §PLUG-104: ours starts beside an ignored crew's running exclusive and passes its waiting one; theirs still waits for ours; a crew never ignores itself; `config` shows the key.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
