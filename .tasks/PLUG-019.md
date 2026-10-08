---
title: docs-manager external docs — ingest flow: read, card, place, move
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

Skill flow for "ingest / catalogue the external docs": for each new or changed file Claude
reads it (pdf natively, page ranges), writes the card incl. a precise `## Where to look`
map, proposes a sub-folder, and — after user confirmation — moves file + card together
and regenerates indexes. Placement is a proposal, never silent.

Binaries placed by the user are committed as-is; the flow never gitignores or deletes them,
and keeps any intermediate output out of the repo.

## Acceptance criteria

1. SKILL.md trigger phrases added (*external docs, ingest, catalogue, reference material*),
   checked against other plugins' vocab and the built-in pdf/docx/xlsx skills.
2. A move helper relocates file + card atomically and reports links it broke.
3. Walk-through on a sample folder (2 pdfs) produces placed, carded, indexed output with
   `docs.sh check` clean.
