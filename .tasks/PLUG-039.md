---
title: kickoff — existing-project mode (A0)
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

When kickoff runs on a project that already has code or a partial setup, it reads what is there, infers
the answers it can (and shows them for confirmation), and asks only about the gaps. The same mode lets
the older projects be brought up to date later.

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034. (question A0)

## Acceptance criteria

- On a fully set-up project it asks nothing and changes nothing.
- An inferred answer is never written without the user confirming it.
- Existing files are never overwritten blindly: a differing file is shown as a diff and needs approval.

## Dependencies

PLUG-035 and PLUG-036.

## Current State

Not started.
