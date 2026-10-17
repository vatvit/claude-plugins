---
title: kickoff — seeded workflow applies SOLID, DRY and INVEST
status: completed
type: feature
epic: kickoff-next
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | below |
| 30 | Assessment | done | global steps: only context, reflection |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | INVEST in requirements, no new step |
| 70 | Tests | done | scaffold.test.sh 2o–2q, 3f, 4o, seen red |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | kickoff README |
## Description

SOLID and DRY are what the user cares about most for code quality. INVEST is how they want tasks split,
created and organised. These are global rules, so kickoff must not restate them in the project CLAUDE.md
(decided 2026-10-09). Instead, the task workflow that kickoff seeds should make them **act**: each one is
checked at the step where it can still change the outcome.

Today neither seeded template mentions them. `templates/workflow-profiles.md` has **no `subtasks` step at
all**, so nothing in a kicked-off project prompts an INVEST split.

## Requirements (negotiable)

- **INVEST** at the step where a task is shaped or split. Either add a `subtasks` step to the code
  profile, or add the check to `requirements`. Decide at Architecture. Prefer vertical slices that each
  satisfy INVEST. Note where a genuine shared dependency forces some coupling.
- **SOLID + DRY** as review points:
  - at `architecture`: one responsibility per module, dependencies point at abstractions, and an
    existing helper is reused rather than cloned;
  - at `implementation`/`tech-debt`: duplication is refactored now or filed as a debt task, never left
    unflagged.
- Each check is one short line in the step description, not a copied essay. Where more is needed,
  link to a step file under `_workflow/steps/`, if the global set has one.
- `workflow-minimal.md` gets the same checks, condensed.
- This changes only **newly seeded** workflows. An existing project's WORKFLOW.md is the user's, and
  scaffold never overwrites a seeded file (3c).

## Acceptance criteria

- A fresh scaffold (both profiles) writes a WORKFLOW.md whose task-shaping step names INVEST, and whose
  architecture and implementation steps name SOLID and DRY.
- Re-running scaffold on a project with an existing WORKFLOW.md leaves it byte-identical.
- The scaffold tests cover both templates.

## Notes

- Files: `kickoff/templates/*.md`, `scripts/test/scaffold.test.sh`. These are disjoint from PLUG-050
  and PLUG-052.
- First check the global `project-tasks/_workflow/` step files, so the wording stays DRY with them.

## Outcome (2026-10-17, kickoff 0.6.0)

- **Decision (Architecture):** INVEST goes into `requirements` (where a task is shaped), no new
  `subtasks` step, so profile shapes stay as they were. SOLID + DRY at `architecture`, DRY at
  `implementation`, duplication left in place at `tech-debt`. Minimal profile: INVEST at `context`,
  SOLID + DRY at `implementation`. One clause each.
- The global `_workflow/steps/` holds only context.md and reflection.md, so there is no step file to link.
- Tests 2o–2q, 4o (both templates through a real scaffold), 3f (an existing WORKFLOW.md stays
  byte-identical on re-run). Seen red before the templates changed, and 3f with the seeding forced.

## Current State

Completed 2026-10-17. Host, `bash:5` container and a sibling-free copy: ALL GREEN.
