---
title: docs-manager skill should activate on diagram requests
status: proposed
type: docs
priority: low
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | — | |
| 20 | Assessment | — | |
| 30 | POC | — | |
| 40 | Domain | — | |
| 50 | Architecture | — | |
| 60 | Tests | — | |
| 70 | Subtasks | — | |
| 80 | Implementation | — | |
| 90 | Tech Debt | — | |
| 100 | Reflection | — | |

## Description

Raised by PLUG-002. `docs-manager/skills/docs-manager/SKILL.md` documents `index`,
`links` and `check`, and its `description:` frontmatter lists only those triggers. The
`diagram` subcommand shipped in PLUG-002 is invisible to the skill, so asking "add a
diagram to this doc" or "update the diagram" will not activate docs-manager.

Held back from the PLUG-002 commit deliberately: changing a skill's `description:`
changes *when the skill fires* across every project that installs the plugin. That is
a behavioural change to activation, not documentation, and deserves its own decision.

## Scope

- extend the SKILL.md `description:` with diagram triggers
- document the source format and `diagram index` in the skill body
- keep the conventions section authoritative — link, do not restate the README

## Open question

How aggressive should activation be? "generate the roadmap"-style phrasing risks
colliding with the `task-roadmap` plugin's triggers, and the two must not fight over
the same prompts. Worth checking `task-roadmap`'s description before widening this one.

## Depends on

PLUG-002 (shipped).
