---
title: "remote-docs: extract decisions from working material into the docs where decisions live"
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

A `truth: no` folder (collaboration, artifacts) is never where a decision lives. When Claude catalogues
or refreshes such material it looks for decisions and proposes writing each into the `truth: yes` doc it
belongs to (applied on approval). An `## Extracted` record (decision → doc) and an `extracted-at` stamp
with one writer; `check` reports `EXTRACT?` when the material changed after the last extraction.

## Acceptance criteria

- Extraction proposed, never applied silently; the record links each decision to its doc.
- `EXTRACT?` seen red then green in tests; one writer of the stamp.

## Current State

Not started. Read epic PLUG-143 (Decisions, Connector facts) first.
