---
title: "remote-docs: write to Drive by folder purpose — stale-write guard, convert to Google format"
status: proposed
type: feature
priority: medium
epic: remote-docs
deps: [PLUG-145]
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

Claude writes to remote documents only where the folder's `writes:` allows it (`propose`: show the edit,
apply on approval). Before every update it re-reads; if the file changed since Claude last read it, warn.
Docs writes carry `requiredRevisionId`; Sheets have no guard, so compare the update time and prefer
`append_values`. Editing an Office file asks to convert it to Google format first (new file, new link;
the card follows the new id; never trash the original without asking: trash cannot be undone through the
connector). The `google-workspace` skill owns the how. Slides: not tested yet, check first.

## Acceptance criteria

- No write in a `writes: never` folder; `propose` never applies without approval.
- A Doc write by a stale read is rejected and re-planned; a Sheet write after a change warns.
- Conversion asked, card re-pointed, original kept unless the user says otherwise.
- Plugin description and trigger phrases updated (read and write per folder purpose).

## Current State

Not started. Read epic PLUG-143 (Decisions, Connector facts) first.
