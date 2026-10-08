---
title: crew — hot-spot holds registry with held-file edit guard
status: completed
type: feature
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | same session as PLUG-026 — its Context/Architecture apply; extension points ready |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | pre-edit hook already calls `holds_guard` via load_area; status.d/msg.d ready |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `crew/scripts/test/holds.test.sh` (34 checks) |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 82/82 (core+holds) host + docker |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | references/holds.md, SKILL.md row, README row; 0.2.0 |

## Description

Hot-spot files: one holder at a time, with the holds kept in a registry instead of in
messages someone might miss (playbook §2, §9.5).

- Hot spots are a list of globs in `.crew.json`, empty by default. Any file can be held,
  hot spot or not.
- `holds.sh hold <path> [--task ID]`, `release <path> --sha <sha>`, `chain <path> <name>…`,
  `who [path]`. They write `.git/crew/holds` under a lock, recording holder, since and task.
  `release` refuses unless the sha is a commit that touched the path.
- A PreToolUse hook on Write/Edit/MultiEdit/NotebookEdit **denies** an edit to a file held by
  another session, naming the holder and the time held since, and suggests `chain`. Editing
  an unheld hot spot is also denied, with the instruction to run `hold` first. `hookMode=warn`
  turns both into warnings.
- A `status.d` part and `msg.d` kinds `hold` / `release` / `chain`, filled from the registry.
- `references/holds.md`.

## Acceptance criteria

- [ ] s1 holds `schema.ts`. s2's Edit is denied with "held by s1 since HH:MM". After s1
      releases with the sha of a commit that touched it, s2's Edit passes.
- [ ] `release` with a sha that did not touch the path is refused.
- [ ] A chain hands the hold to the next session in the chain on release.
- [ ] `hookMode=warn` prints the same reason to stderr and lets the edit through.
- [ ] Concurrent `hold` calls on one path: exactly one wins.
- [ ] The suite passes in docker and from a standalone copy.

## Architecture

- `crew/scripts/holds.sh`: dual-use. Sourced → `holder_of`, `hot_spot`, `hold_desc`, `holds_guard`;
  executed → `hold | release | chain | who | drop` (dispatched by `crew.sh`).
- Registry `<state>/holds` TSV (path, holder, since, task, chain); `holds.log` records releases
  (time, path, from, to, sha) so `msg release` can announce without asking.
- Release proof: the sha must be a commit on the current branch (`merge-base --is-ancestor`) that
  touched the path (`diff-tree --root`); `--unchanged` instead only when the path is clean.
- A non-holder may release only if it is the coordinator; `drop` is coordinator-only.
- Unnamed sessions are denied on any held path and on unheld hot spots (with the join hint).

## Implementation

`holds.sh`, `status.d/holds.sh`, `msg.d/holds.sh` (hold, release, `msg_handoff_extra_holds`),
`holds.test.sh` 34/34; full run 82/82 on host and in `crew-test`.

## Reflection

- Skill pointer row + `references/holds.md`; README command row; plugin 0.2.0 + marketplace synced.
- No new lessons for repo docs.
- **New finding from the user (2026-10-08):** several coordinators across repos can share names, and
  SendMessage addresses are machine-wide → filed as a new crew sub-task (cross-crew isolation).

## Current State

Completed. Build green.
