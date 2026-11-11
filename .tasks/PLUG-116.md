---
title: "docs-manager — processed: remote for a Drive attachment: write the <doc>.md to Drive, asked once"
status: rejected
type: feature
priority: low
epic: docs-gdrive
deps: [PLUG-115]
created: 2026-11-11 18:02
tags: ["docs-manager-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | epic PLUG-110 (option 3); POC findings on write access |
| 20 | Requirements | — | where on Drive (beside the source? a sub-folder?), naming, overwrite rules |
| 30 | Assessment | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | red first, offline: the ask is recorded and not repeated; card points at the remote processed copy |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

With `processed: remote`, Claude writes the processed `<doc>.md` to Drive instead of the repo. Mainly
offered when `processed: local` is declined. Writing to Drive is outward-facing (possibly a folder
shared with others), so the plugin asks once per attachment and records the answer in `.source.md`.

The card then points at the remote processed copy, which Claude reads before the original when it
needs the content.

## Acceptance criteria

- Nothing is written to Drive before the user agreed; the answer is recorded and not asked again.
- The card links the remote processed copy; refresh notices when the source is newer than the copy.
- With no write access, Claude says so and falls back to `none`.

## Decision (2026-11-11, the user)

Rejected. The connector already returns any Drive file as text on demand (`read_file_content`), so a
processed copy on Drive adds nothing for reading; and `update_file` cannot change content, so every
refresh would create a new file and trash the old one in a possibly shared folder. Offline reading is
PLUG-115's local copy.

## Current State

Rejected.
