---
title: docs-manager — where do decisions live? Its convention says task files, many projects keep them in docs/
status: proposed
type: improvement
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

Found while checking the spec-driven slide (PLUG-058) against the plugins.

docs-manager's convention (`docs-manager/skills/docs-manager/SKILL.md`, "Docs reflect the ACTUAL
current state") puts "rejected options, decisions" in task/issue files, not in `docs/`. The user's
own working rules put "decisions and their reasons" in `docs/`, and tasks only keep what was done
and why. `how-to-claude-md.md` in the same plugin already points to a "decision record" in a doc,
so the plugin is not consistent with itself either.

The two can be reconciled: the *current* decision and its reason are current state (a doc), while
the history of how it was reached (options weighed, rejected alternatives over time) is history (a
task). Today the convention lumps both under "history".

## Open questions

- Is a decision + its reason current state (docs) or history (tasks)? Proposed: the standing
  decision and its reason live in docs; the deliberation lives in the task that made it.
- Where in `docs/` — a section in the doc it governs, or a decisions folder?
- Once agreed: update SKILL.md and how-to-claude-md.md together, and the slide's docs-manager box
  if it should then mention decisions.

## Current State

Proposed. Nothing changed yet.
