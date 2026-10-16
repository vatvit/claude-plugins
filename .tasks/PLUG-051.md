---
title: kickoff — seeded workflow applies SOLID, DRY and INVEST
status: proposed
type: feature
epic: kickoff-next
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

## Current State

Proposed, backlog for the next kickoff release (epic PLUG-049). Not started.
