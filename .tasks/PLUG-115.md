---
title: "docs-manager — processed: local for a Drive attachment: a stamped <doc>.md text copy, asked once"
status: proposed
type: feature
priority: low
epic: docs-gdrive
deps: [PLUG-112]
created: 2026-11-11 18:02
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | epic PLUG-110 (option 1); extract.sh, which already extracts docx/xlsx/pptx text |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | red first, offline: the ask is recorded and not repeated; a stamp older than the source is reported stale |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

With `processed: local`, Claude keeps a readable `<doc>.md` text version of a complex file next to its
card, so the user can work offline, at their own risk. It goes against docs-manager's default "only the
card goes into the repo", so the plugin asks once per attachment and records the answer in `.source.md`.
Whether the copy is committed or gitignored is part of the same question.

The copy is stamped with the source's modifiedTime; `check` / refresh report it as stale when the source
is newer. When Claude answers from it, it says the answer comes from a local copy of a given date.

## Acceptance criteria

- No `.md` copy is written before the user agreed; the answer is recorded and not asked again.
- A stale copy is reported by `check`.
- For a synced local file, text comes from extract.sh (no second extractor).

## Current State

Proposed. After PLUG-112; can run alongside PLUG-113 and PLUG-114. PLUG-116 builds on it.
