---
title: kickoff — interview to charter (plugin skeleton, sections A–F)
status: in-progress
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

The first vertical slice. The kickoff skill runs questionnaire sections A–F one section at a time, with
"accept all defaults" or change some. It writes the answers file and `docs/project/charter.md`, which
holds what the project is, the goal, the gate, scope, non-goals, a numbered decisions table with a why
for each, and the open questions.

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034.

## Acceptance criteria

- Plugin skeleton: `kickoff/.claude-plugin/plugin.json`, a marketplace entry, and a row in the repo
  CLAUDE.md Plugins table. Trigger words do not clash with the other plugins.
- Branching works: a question whose *Ask when* is false is skipped. A3 and A4 change the defaults.
- "Not decided yet" lands under Open questions, never as a guessed decision.
- The charter is generated from the answers file by a script, and that script has tests. Replaying the
  sample-poc answers yields its decisions D1–D5 and D7.
- Re-running with unchanged answers changes nothing (diff-guarded write).

## Dependencies

None. This slice owns the hot spots `plugin.json`, `marketplace.json` and `SKILL.md` first.

## Current State

Not started.
