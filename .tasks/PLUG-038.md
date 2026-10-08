---
title: kickoff — per-account defaults (kickoff.json)
status: proposed
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

`${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json` overrides the questionnaire's ★ defaults for one account.
For example, a work account defaults to "employer's project" and "tasks outside the repo".

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034.

## Acceptance criteria

- Every key is optional, and an absent file or key falls back to the ★ default. Watch the
  `pipefail` trap noted in the repo CLAUDE.md.
- Two accounts with different `CLAUDE_CONFIG_DIR` values get their own defaults. A test proves it.
- The defaults that depend on earlier answers (A3, A4) still apply where the file says nothing.

## Dependencies

PLUG-035.

## Current State

Not started.
