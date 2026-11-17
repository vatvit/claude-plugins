---
title: "Ukrainian Claude Desktop guides: add the Cowork screenshots"
status: proposed
type: docs
priority: medium
tags: ["docs-manager-plugin", "remote-docs-plugin", "task-plugin"]
created: 2026-11-17 14:14
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

## Problem

PLUG-151 shipped the two guides (`docs/guides/uk/01-docs-manager-remote-docs.md`, `02-task.md`) with
blockquote slots `[Знімок екрана: …]` in place of screenshots: 11 in Part 1, 4 in Part 2. The install
steps in Part 1 are worded generically ("open the plugins section…") because the Cowork UI was not seen.

## Acceptance Criteria

- The user's Cowork screenshots in `docs/guides/uk/images/`, named by step; every slot replaced by its image.
- Every install step re-worded to match what the screenshots show; nothing taken from the CLI flow.
- Optional: one screenshot of an artifact with comments, in the Artifacts tip (offered in PLUG-151).
- `bash docs/guides/build.sh`; both PDFs read back, images visible; second run `unchanged`.

## Current State

Proposed. Waiting for the user's screenshots.
