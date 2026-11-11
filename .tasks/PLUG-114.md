---
title: "docs-manager — content: sync for a Drive attachment: copy and export into the repo, ask above a size limit"
status: rejected
type: feature
priority: low
epic: docs-gdrive
deps: [PLUG-112]
created: 2026-11-11 18:02
tags: ["docs-manager-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | sync via this connector means Claude retyping base64; see Context |
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

## Context

- **How bytes reach the repo.** The connector's `download_file_content` returns the file as base64 *in
  Claude's context*; no tool writes to disk. Probe (2026-11-11, test folder): a one-paragraph Google Doc
  exported as docx is ~9 KB, ~12 KB of base64 inline. To land it in the repo Claude must re-emit every
  character in a Write call (then `base64 -d`): the cost is paid twice, input and output, and one
  wrong character corrupts a binary. Claude Code's saving of large tool results to a file is an
  internal detail, not something a plugin can rely on.
- **Integrity cannot be checked.** The listing has no md5 or checksum (POC); `fileSize` exists only for
  uploaded files, not for exports. A corrupted copy would be stamped and trusted.
- **Text exports are different.** A Doc exports as `text/markdown`, a Sheet as `text/csv`: plain text,
  no base64, and readable as is. But a Doc's markdown export is exactly what PLUG-115 (`processed:
  local`) stores, so text sync and PLUG-115 overlap.
- **What a synced binary would give** over a remote card: the existing digest / stamp / `check` flow and
  `extract.sh`. It is the same as the user downloading the file into `docs/external/` by hand, which
  the plugin already supports.

## Decision (2026-11-11, the user)

Rejected as specced. Copying files through the connector means retyping base64 with no checksum to catch
a corrupted byte (Context). Instead:
- **Text** copies of native Docs / Sheets (markdown / csv exports) are PLUG-115's `processed: local` copy;
  no separate `content: sync`.
- **Binaries** (uploaded pdf, docx, …) stay remote. A user who wants one locally downloads it into
  `docs/external/` by hand; it is then an ordinary external file, and the existing card / stamp / `check`
  flow covers it. PLUG-115's how-to says so.

## Current State

Rejected. Scope moved to PLUG-115.
