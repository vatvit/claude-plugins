---
title: kickoff — setup scaffold (sections R and K)
status: proposed
type: feature
epic: kickoff
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | Architecture | — | |
| 50 | Tests | — | |
| 60 | Implementation | — | |
| 70 | Tech Debt | — | |
| 80 | Reflection | — | |

## Goal

From the answers to sections R and K, write `.task-config.json` and the task workflow, the `docs/`
skeleton with its `_index.md` files, a small project CLAUDE.md that holds instructions and pointers
only, and the first tasks: agree the charter, the architecture overview, and the dev harness with the
first slice.

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034.

## Acceptance criteria

- Uses task, docs-manager, crew and task-roadmap when installed, and falls back to plain files when they
  are not.
- The generated CLAUDE.md copies no global rules. It holds only R1–R5, E3 and E5, plus a pointer to the
  charter.
- Idempotent: an unchanged file is never touched.

## Dependencies

PLUG-035 (skeleton, answers file).

## Current State

Not started.
