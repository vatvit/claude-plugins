---
title: kickoff — setup scaffold (sections R and K)
status: completed
type: feature
epic: kickoff
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | |
| 20 | Requirements | done | |
| 30 | Assessment | done | |
| 40 | Architecture | done | |
| 50 | Tests | done | |
| 60 | Implementation | done | |
| 70 | Tech Debt | done | |
| 80 | Reflection | done | |

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

## Context

- Builds on PLUG-035 (answers, `lib.awk`) and PLUG-037 (the I5 registry).
- **The task skill's data contract** (`task/skills/task/references/configuration.md`):
  - project-local `.task-config.json`;
  - for tasks outside the repo, `<global>/config.json` keyed by project path, where `<global>` is `$CLAUDE_CONFIG_DIR/project-tasks` first, then `~/.claude/project-tasks`;
  - a `_workflow/WORKFLOW.md` inside the tasks dir overrides the global one.
- **The global workflow has no profiles.** project-c defines code and docs profiles in its own WORKFLOW.md.
- **docs-manager:** every folder has an `_index.md` with `title` / `description` frontmatter, and its `index --write` fills the AUTO-INDEX blocks.
- **crew** needs no project file: sessions join with `whoami`.
- **task-roadmap** needs no file when its defaults apply. So R5 and R9 produce no config.

## Architecture

- `scaffold.sh` refuses to run while `plan.sh --next` is non-empty. It reads only settled answers (`settled()` moved into lib.awk; `get.awk` exposes it to the shell).
- **Seeded files are written once and then belong to the user:** `_index.md`, `.task-config.json`, WORKFLOW.md. **CLAUDE.md is generated** (`claude.awk`): it is rewritten while unchanged and refused (exit 3) once edited.
- **Tasks outside the repo:** the scaffold inserts an entry into the task skill's per-account registry and keeps the existing projects. The client repo's CLAUDE.md describes the location in prose and never prints the path, because the path contains the user's home directory (identity rule).
- **Workflows** are `templates/workflow-profiles.md` (code and docs, after project-c) and `templates/workflow-minimal.md`. Step definitions stay global and are not copied.
- **Deviation:** kickoff does not write the first tasks. Allocating ids is the task plugin's job, so the scaffold names the three tasks and the skill creates them with `/task create`.

## Tests

`scripts/test/scaffold.test.sh`, 38 checks, green on the host and in `bash:5`. Coverage:
- the guards;
- an own project and a client's PoC, including registry insertion, keeping the other entries, no duplicate entry, the per-account registry, and no home path in CLAUDE.md;
- re-runs: nothing changes, a seeded file is never overwritten, an edited CLAUDE.md is refused;
- game and minimal docs.

`helpers.sh` gains `autofill`, which answers a whole questionnaire with defaults plus overrides.

**Shown failing:** when tasks-outside is ignored, 7 checks fail (4b–4m); when seeded files are overwritten, 3 fail (3a–3c).

## Implementation

- `scaffold.sh`, `claude.awk`, `get.awk`, `templates/`.
- SKILL step 6: run the scaffold, run docs-manager's index, create the first tasks.
- README and CLAUDE.md updated. 0.2.0 → 0.3.0 in plugin.json, the marketplace and SKILL.md, with the descriptions refreshed and a "scaffold the project" trigger added.
- Found while testing: backticks inside a double-quoted shell string run as a command substitution. The value is now single-quoted.

## Tech Debt

None.

## Reflection

kickoff/CLAUDE.md, Don't regress: the two kinds of generated file, no user identity in a client repo, generators read only settled answers.

## Current State

Completed. Next: PLUG-038 (per-account defaults).
