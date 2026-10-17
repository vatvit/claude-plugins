---
title: crew — `crew active` probe, and the guide for working solo and per-mode project rules
status: completed
type: feature
epic: crew-solo
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | crew/CLAUDE.md, slots/adopt refs, field report |
| 20 | Requirements | done | below |
| 30 | Assessment | done | crew_active exists; whoami/SessionStart are the member touchpoints |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | active.sh; crewRules key + crew_rules_print |
| 70 | Tests | done | active.test.sh, seen red |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | crew/CLAUDE.md, root CLAUDE.md, solo.md |

## Description

Project CLAUDE.md files carry rules that only make sense while a crew runs (hot spots, keep red work off
the tree, land with apply, check the commit list before push). A project going solo has to hand-split
them, and a hook or script has no clean way to ask "is a crew running here?".

## Requirements (negotiable)

- `crew active`: exit 0 when a crew runs in this repo, 1 when not; on 0, one line: members and roles,
  and this session's name/role if it is in it. No output on 1, so `if crew active; then …` reads cleanly.
- A README and skill section: **working solo**, **ending a crew** (points to PLUG-075's `crew end`), and
  **project rules per mode**: a copyable CLAUDE.md pattern with an "always" block and a "while a crew is
  running" block, plus a hook snippet that uses `crew active`.

## Acceptance criteria

- `crew active` exits 0 with the one-liner in a fixture crew, 1 with no output in a repo without one,
  and 1 outside git (no crash).
- The guide's CLAUDE.md pattern and hook snippet are checked by a test (the snippet runs against both
  fixtures), so the doc cannot drift from the command.
- Suite green on host and `bash:5`, and from a copy of `crew/` alone.

## Notes

- Files: `crew/scripts/crew.sh` (dispatch), small probe in `lib.sh`/`status.sh`, a new
  `skills/crew/references/` guide, README, `scripts/test/`.
- PLUG-075 is referenced by the guide but not required: write the "ending a crew" part against what
  exists when this lands.

## Outcome (2026-10-17, crew 2.2.0)

- `crew active` (`scripts/active.sh`): exit 0 + `crew <id>: <members>[ · you: <name> (<role>)]`, exit 1
  silent with no crew and outside git.
- **Decision (the coordinator's, made at Architecture):** besides the guide, crew carries the per-mode
  split itself. New project-only key `crewRules` names a file in the tree (checked like `treeLink`);
  `crew_rules_print` (lib.sh) shows it to a member on join and at SessionStart, never to a non-member.
  So crew-only rules cost a solo session nothing and need no project hook. (A project hook could not
  rely on `crew` anyway: the plugin's `bin/` is on the Bash tool's PATH only.)
- Guide `skills/crew/references/solo.md`: is a crew running, ending a crew, rules per mode (links
  adopt.md for the rules crew enforces instead of repeating them), machine time when a repo has no crew.
- Tests `active.test.sh` (17): exit codes, the one-liner, crewRules shown to members only, refused
  outside the tree and in the user layer, and the guide's snippet run as written in both modes.
  Seen red: before the code (9 failing), and with `crewRules` dropped from `cfg_project_only`.

## Current State

Completed. Host, `bash:5` container and a sibling-free copy of `crew/`: ALL GREEN.
