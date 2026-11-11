---
title: "docs-manager — attach a Google Drive folder and refresh it: new / changed / orphaned cards"
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
| 10 | Context | — | epic PLUG-110; the existing external staleness check (new / changed / orphaned) to reuse, not clone |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 60 | Architecture | — | listing TSV: id, path, mimeType, modifiedTime, size |
| 70 | Tests | — | red first, offline: fixture listings vs fixture cards → new / changed / gone; include/exclude; recursive |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

A `.source.md` can point at a Drive **folder** with a scope (recursive, include / exclude). On
"refresh the Drive docs", Claude lists the folder through the MCP into a temp file; a script compares
that listing with the attachment's cards (file id + modifiedTime) and reports new, changed and gone.
Claude writes cards for new files and updates changed ones. A card whose file is gone is marked
orphaned, never deleted.

The comparison must reuse the existing external-docs staleness logic where it fits (DRY within the plugin).

## Acceptance criteria

- Refresh reports exactly the new / changed / gone files for fixture listings.
- Orphaned cards are marked and reported by `check`, not deleted.
- Include / exclude and recursive scope are honoured.
- Tests need no network and no MCP.

## Current State

Proposed. After PLUG-112; can run alongside PLUG-114 and PLUG-115.
