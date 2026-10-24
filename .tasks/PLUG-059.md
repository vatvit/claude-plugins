---
title: docs-manager — where do decisions live? Its convention says task files, many projects keep them in docs/
status: completed
type: improvement
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | SKILL.md conventions, how-to-claude-md table |
| 20 | Requirements | done | the user decision recorded above |
| 30 | Assessment | done | docs-only change |
| 40 | POC | skipped | — |
| 50 | Domain | skipped | — |
| 60 | Architecture | skipped | — |
| 70 | Tests | skipped | no behaviour change; docs check of the plugin unaffected |
| 80 | Subtasks | skipped | — |
| 90 | Implementation | done | SKILL.md bullet, how-to-claude-md rows, README line |
| 100 | Tech Debt | skipped | — |
| 110 | Reflection | done | the rule itself is the reflection |

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

## Decision (2026-10-24, the user)

Discussion and rejected options belong in the task. The final decision and its consequences belong in
`docs/`. When the project keeps tasks, the doc links to the task. Applied in docs-manager's SKILL.md
(convention "A decision is split in two"), `how-to-claude-md.md` § Where knowledge goes (two rows) and
README's conventions line. Where in `docs/`: the doc the decision governs (as the how-to already said);
no decisions folder. The slide names no decisions, so it is unchanged.

## Result (2026-10-24)

The conventions now separate a decision into two parts. The decision and its consequences live in
the doc it governs. The options weighed and rejected stay in the task, and the doc links to that task
when the project keeps tasks. Changed: SKILL.md (conventions), how-to-claude-md.md (the
"where knowledge goes" table) and README. Released in docs-manager 1.10.0.
