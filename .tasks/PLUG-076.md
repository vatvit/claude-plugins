---
title: crew — `crew active` probe, and the guide for working solo and per-mode project rules
status: proposed
type: feature
epic: crew-solo
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

## Current State

Proposed 2026-10-17 (epic PLUG-073). Not started.
