---
title: "remote-docs: extract decisions from working material into the docs where decisions live"
status: completed
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
| 10 | Context | done | epic Decisions (truth: no material), PLUG-141 artifact rule, PLUG-145 resolver |
| 20 | Requirements | done | ## Requirements |
| 30 | Assessment | done | ready: PLUG-148 landed (bea20e3) |
| 40 | POC | skipped | offline bookkeeping only; no connector behaviour to prove |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | EX1a–e, EX2 ×3, EX3, EX4, EX5, seen red (7 failing) first; AR1c/AR5b rescoped |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | remote-docs CLAUDE.md (Extracting decisions; stale source_of / layout / stamp-writer lines fixed), how-to, README (plugin + root, upgrade note), SKILL, root vocabulary |

## Description

A `truth: no` folder (collaboration, artifacts) is never where a decision lives. When Claude catalogues
or refreshes such material it looks for decisions and proposes writing each into the `truth: yes` doc it
belongs to (applied on approval). An `## Extracted` record (decision → doc) and an `extracted-at` stamp
with one writer; `check` reports `EXTRACT?` when the material changed after the last extraction.

## Acceptance criteria

- Extraction proposed, never applied silently; the record links each decision to its doc.
- `EXTRACT?` seen red then green in tests; one writer of the stamp.

## Requirements

Acceptance criteria above, with the approved plan (2026-11-16). Asked: every artifact card, and every card
in a folder that *declares* `truth: no` and is not `reference`; pointer cards included. Not asked: an
undeclared folder (its fallback is a default, not a statement).

## Architecture

- `wants_extraction <card> <root>`: the one rule above.
- `status` adds an `extract` row after a complete card whose `extracted-at` is missing or differs from
  `remote-modified`; `check` prints it as a failing `EXTRACT?`.
- `remote.sh extracted <card>`: the only writer of `extracted-at:` (set to the current
  `remote-modified`); refuses an incomplete card; `UNCHANGED` when already current. `stamp` never
  touches it, so a newer file asks again.
- Card section `## Extracted`: `- <decision> → [doc](link)`; how-to *Extracting decisions*.

## Implementation (2026-11-16)

As designed. Two artifact tests changed scope, not meaning: AR1c now records the review before expecting
a clean `check`, and AR5b checks for a `REMOTE KEY` line rather than any mention of the card. Suite 169
green on host and `bash:5` + git; 164 + 3 skipped in plain `bash:5`, without HOME, with a read-only HOME
and copied out alone. docs-manager suites unchanged and green.

**Upgrading:** existing artifact cards and cards in `collaboration` / `output` folders fail `check` until
reviewed once; the README says so.

## Current State

Completed 2026-11-16. Last sub-task of epic PLUG-143.
