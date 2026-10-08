---
title: docs-manager external docs — card format + index integration
status: proposed
type: feature
priority: medium
epic: external-docs
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

Define the card that sits beside an external file and make it show up in `_index.md`.
Format per the epic's Design section. Base for every other sub-task.

## Acceptance criteria

1. Card format documented in the skill (one home — a reference file or SKILL.md section).
2. A hand-written card for a sample pdf appears in the folder's `_index.md` with its
   `description`; the binary itself is not listed separately.
3. `docs.sh links` resolves a link from a project doc to a card and to the binary.
4. Layout per the epic: externals under `docs/external/<topic>/`; the root is a single
   optional `.docs-manager.json` key with default `docs/external`. `docs/external/_index.md`
   lists topic folders like any other docs folder.
5. Test in `scripts/test/` covers 2–4; passes on host bash 3.2 and bash:5 container.
