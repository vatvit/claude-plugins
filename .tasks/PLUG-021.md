---
title: docs-manager external docs — flag related docs when a source changes
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

When a card is reported **changed** (sub-task PLUG-018), list the project docs in its
`relates-to:` — and any doc linking to the card or binary — as "review needed". The skill
then proposes concrete updates; project docs cite card locations rather than copying text.

## Acceptance criteria

1. `docs.sh check` output for a changed source includes its related docs.
2. Back-links (docs linking the card/binary) are found without a second link parser.
3. Skill section on refreshing docs from a changed source; user approves each edit.
4. Tests; host + container.
