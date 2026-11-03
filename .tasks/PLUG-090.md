---
title: crew — memory-aware slots and named slot groups, so single-thread jobs run side by side and only memory-heavy runs exclude each other
status: completed
type: feature
priority: high
deps: [PLUG-096]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | slot.sh after PLUG-096; plan fields 11-15 read by watch.sh, msg.d/slots.sh, slot_line |
| 20 | Requirements | done | as in Scope; plus: no passing an earlier competing slot |
| 30 | Assessment | done | rows gain fields 11-12; old rows read as 0 GB, no group |
| 40 | POC | skipped | no risky unknown |
| 60 | Architecture | done | see Implementation |
| 70 | Tests | done | slotmem.test.sh (17), red first; mutants per rule |
| 90 | Implementation | done | slot.sh, lib.sh, config.sh |
| 100 | Tech Debt | done | none taken |
| 110 | Reflection | done | slots.md, config.md |

## Description

Slot classes today are CPU-shaped: `cpu` runs with other cpu slots, `exclusive` with nothing. In practice the
limit is often **memory**, not CPU. Observed in a crew of three workers: a heavy Blender build used about 1 core of 12
but about 10 GB of a 16 GB Docker VM. Two such builds were OOM-killed (exit 137) when run side by side, so they were
moved to `exclusive`, and every short test slot then waited 30 min behind a build that left 11 cores idle.

What the crew needed: "at most one of THESE at a time, anything else alongside", and "admit work while it fits in
memory".

## Scope

- `slot run cpu <min> --mem <GB>`: a slot declares its memory. A machine budget (config, user scope) admits cpu slots
  while the declared sum fits; a slot that would overflow waits like any other.
- `--group <name>`: a named mutex group. At most one running slot per group (e.g. `--group heavy-build`), other
  slots run alongside.
- `slot list` shows each slot's mem and group, and the budget in use.
- Defaults keep today's behaviour: no --mem means 0, no group means none.

## Acceptance

- Two slots in one group never overlap; a third slot without a group runs beside them.
- With a 14 GB budget, a 10 GB slot and two 2 GB slots run together; a second 10 GB slot waits.
- Tests seen red first.

## Also seen

A project-side lock written by the child process could record the holder's pid, member name and start time, but not
the slot id: `slot run` exports nothing about the slot to its child. Export the slot id (and class, mem, group) as
environment variables to the command, so a child can name the slot it runs in.

## Implementation (2026-11-03)

- **Row and plan.** A slot row gains `mem` (GB) and `group` as fields 11-12; a row written before has neither and
  reads as 0 GB, no group. `slots_plan` prints fields 1-10, its five computed fields at 11-15 as before, then mem
  and group at 16-17, so `watch.sh`, `msg.d/slots.sh` and `slot_line` needed no change for the old fields.
- **Budget.** New key `slotMemGB` (project, user; default 0 = no budget), in `CREW_KEYS`, `cfg_default` and
  `key_type`. With a budget, a waiting `cpu` slot that declares memory starts while running + admitted memory
  fits; a slot larger than the budget starts only when no memory is in use. One held back for memory holds back
  every later slot that declares memory, and its ETA is when memory frees (conservative: the latest end of the
  memory-using slots ahead).
- **Groups.** `--group <word>`: a slot whose group has a running or earlier-queued slot waits until that one's end.
- **No passing (generalises PLUG-096).** Shortest-first let a shorter 2 GB slot pass a waiting 10 GB one, the
  same starvation. `_slots_no_pass` is now one rule: slot j blocks a later-requested i (prio no better) when they
  compete (cpu vs exclusive/quiet; both declare memory under a budget; same group); repeatedly the first slot in
  shortest-first order with no blocker left goes next.
- **Child env.** `slot run` passes `CREW_SLOT_ID`, `CREW_SLOT_CLASS`, `CREW_SLOT_MEM`, `CREW_SLOT_GROUP` to its
  command (values, never executed).
- `slot list` shows ` · 10G` and ` · group NAME` per slot, and `memory: U of B GB in use` under a budget.

**Tests.** New `slotmem.test.sh` (17): group mutex with an ungrouped slot beside it, no-budget behaviour, the
14 GB acceptance (10+2+2 run, a second 10 waits, a 0 GB slot runs beside, a fitting 2 GB does not pass the
waiting 10), a slot over budget runs alone, input validation, the child env. 16 red before the code. Mutants,
each rule removed in turn: cpu-vs-exclusive pass → slots 8 / crosscrew 1 red; memory pass → 1 red; group mutex
→ 2 red; budget → 4 red. Host and container green (slots 39, slotmem 17, crosscrew 27).

