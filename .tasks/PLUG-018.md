---
title: docs-manager external docs — staleness check (new / changed / orphaned)
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

`docs.sh check` (and a dedicated subcommand) reports external files that are **new** (no
card), **changed** (card `digest` ≠ file sha256) and **orphaned** cards (source missing).
sha256 via `shasum -a 256` / `sha256sum`, one helper in `lib.sh`. Never hashes a path.

## Acceptance criteria

1. Each of the three states is reported with the file path; clean tree reports nothing.
2. A `--stamp` (or similar) writes the current digest into a card, diff-guarded.
3. Which extensions count as "external" is one list, configurable via `.docs-manager.json`
   with a working default.
4. Tests for all states; host + container.
