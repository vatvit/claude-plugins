---
title: "docs-manager — content: sync for a Drive attachment: copy and export into the repo, ask above a size limit"
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
| 10 | Context | — | epic PLUG-110; POC findings on export formats |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | red first, offline: synced file + card → external digest/stamp flow; size check asks above the limit |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

With `content: sync`, Claude copies each attached file into the attachment folder. Google formats are
exported (Doc→docx/md, Sheet→xlsx/csv, Slides→pdf, final mapping from the POC). A synced copy then
becomes an ordinary external file: the existing digest / stamp / `check` flow covers it.

Before a sync that would copy more than N files or X MB (defaults decided at Requirements, overridable),
the plugin asks.

## Acceptance criteria

- A synced file is catalogued exactly like a dropped-in external file; `check` sees its digest.
- Above the limit, the plugin asks before copying; below it, it does not.
- Switching an attachment from `remote` to `sync` (and back) is defined and tested.

## Current State

Proposed. After PLUG-112; can run alongside PLUG-113 and PLUG-115.
