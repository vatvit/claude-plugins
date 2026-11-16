---
title: "remote-docs: cards on Drive, shared with the team"
status: proposed
type: feature
priority: medium
epic: remote-docs
deps: [PLUG-146, PLUG-147]
tags: ["remote-docs-plugin"]
created: 2026-11-16 14:55
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

When the user chooses it for an attachment, the cards live on Drive so every teammate's Claude reads the
same map. Cards on Drive are edited by several sessions, so they go through the same stale-write guard. The
scripts work offline on local files: Claude pulls the cards into a temp listing for them. Consider one
card document per folder (one read per folder instead of one per file).

## Acceptance criteria

- Attach, refresh and check work with cards on Drive as with local ones.
- Two sessions updating cards never overwrite each other silently.

## Current State

Not started. Read epic PLUG-143 (Decisions, Connector facts) first.
