---
title: "crew — say plainly that without HOME each repo has its own slot queue"
status: completed
type: docs
priority: low
tags: ["crew-plugin"]
created: 2026-11-11 19:37
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-119 trade-off; notice in slot.sh `slot_scope_note`, slots.md *Scope* |
| 20 | Requirements | done | criteria in task |
| 30 | Assessment | done | notice said 'not shared with other crews' but not the consequence |
| 40 | POC | skipped | n/a |
| 50 | Domain Lens | skipped | n/a |
| 60 | Architecture | skipped | wording only |
| 70 | Tests | done | home.test.sh: the notice names the consequence (3 modes), red on the old wording |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done | slot.sh notice; references/slots.md *Scope* |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | slots.md is the one home; crew CLAUDE.md already records the rule |

## Description

Accepted trade-off from PLUG-119 (epic cowork, PLUG-117). Without a usable HOME the slot queue falls back to
`.git/crew/`, so two repos on one machine do not see each other's slots, and both may run an exclusive job at
once. The user decided this: machine scope requires HOME. But it is stated only in the code and in PLUG-119, so a user
relying on slots to protect the machine does not learn it.

## Acceptance criteria

- The once-per-crew fallback notice (`slots: project scope — HOME not writable …`) says the queue no longer covers
  other repos on this machine.
- `references/slots.md` says it once, next to `slotScope`, and `slotScope: project` with HOME usable has the same
  consequence.
- The notice wording is pinned by an existing or new check in `home.test.sh`.

## Result (2026-11-11)

- The fallback notice now reads: "slots: project scope — HOME not writable, so this queue covers only this repo: crews in
  other repos on this machine do not wait for its slots, nor it for theirs, and an exclusive slot here does not keep their
  runs off the machine (slotScope in .crew.json)".
- `references/slots.md` *Scope* says the same, once, for both `slotScope: project` and the no-HOME fallback, and adds that
  machine scope needs a usable HOME.
- `home.test.sh` pins the wording in all three no-HOME modes. Against the committed `slot.sh` it fails 3 checks.
- Full crew suite: 958/958 in `crew-test`. On the host, one run had 1 failure that did not repeat in 4 further runs (958,
  then 968/968 ×3 as another session's crew work added checks). Its log was lost, so it is not named. The likely cause
  is that session's crew edits landing during the run; this is not confirmed.
