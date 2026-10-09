---
title: crew — adopt mid-project: config set, hold import, adoption guide
status: proposed
type: feature
epic: crew-feedback
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

Feedback #4. Adopting crew mid-project has no import path. Today the hot spots live in the
project's CLAUDE.md, the holds in a hand-kept `_holds.md` bullet list, and `hotSpots` in crew is
empty.

- **`crew config set|unset [--user] <key> <value…>`** writes `.crew.json` (or the user file),
  validating key and layer. An array key such as `hotSpots` takes several values.
- **`crew hold import <file> [--dry-run]`**: one hold per bullet `- <path> — <holder> (…)`. The
  separators `—`, `-`, `:` and `by` are all accepted. A holder that is not in the crew is
  reported, not invented, and `--dry-run` shows the plan.
- **`references/adopt.md`:** the mid-project checklist:
  1. set the hot spots;
  2. import the holds;
  3. everyone joins (automatic with titled sessions);
  4. cut the hand-written session rules from the project's CLAUDE.md that crew now enforces,
     keeping the project-specific ones;
  5. pick the committer mode.
- SKILL pointer row; README.

## Acceptance criteria

- [ ] `config set hotSpots a.ts 'src/*.ts'` writes a valid `.crew.json`, keeping other keys.
      `config set --user sharedBranch x` is refused, because the key is project-only.
- [ ] `hold import` on a sample bullet file creates the holds. An unknown holder is listed, not
      held. `--dry-run` changes nothing.
- [ ] `adopt.md` exists and SKILL points to it.
- [ ] Suites pass on host + docker.
