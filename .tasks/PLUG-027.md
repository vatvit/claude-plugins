---
title: crew — hot-spot holds registry with held-file edit guard
status: proposed
type: feature
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

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
