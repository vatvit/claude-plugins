---
title: "remote-docs: write to Drive by folder purpose — stale-write guard, convert to Google format"
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
| 10 | Context | done | epic Connector facts (tested 2026-11-16), the PLUG-145 resolver |
| 20 | Requirements | done | ## Requirements |
| 30 | Assessment | done | ready: PLUG-146 landed (3818007) |
| 40 | POC | skipped | Docs/Sheets/Office covered by the epic's tested connector facts; Slides untested and no Slides connector in this session: documented as unguarded until tested |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | WG1–8, RP1–4, seen red (15 failing) first |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | Slides check left open: see ## Implementation |
| 110 | Reflection | done | remote-docs CLAUDE.md (Writing), how-to, README (plugin + root), SKILL, description, root vocabulary |

## Description

Claude writes to remote documents only where the folder's `writes:` allows it (`propose`: show the edit,
apply on approval). Before every update it re-reads; if the file changed since Claude last read it, warn.
Docs writes carry `requiredRevisionId`; Sheets have no guard, so compare the update time and prefer
`append_values`. Editing an Office file asks to convert it to Google format first (new file, new link;
the card follows the new id; never trash the original without asking: trash cannot be undone through the
connector). The `google-workspace` skill owns the how. Slides: not tested yet, check first.

## Acceptance criteria

- No write in a `writes: never` folder; `propose` never applies without approval.
- A Doc write by a stale read is rejected and re-planned; a Sheet write after a change warns.
- Conversion asked, card re-pointed, original kept unless the user says otherwise.
- Plugin description and trigger phrases updated (read and write per folder purpose).

## Requirements

Acceptance criteria above, with the approved plan (2026-11-16). The writes themselves are Claude's,
through the connectors and the `google-workspace` skill; the plugin decides whether and where, and
backs that with a script so it is testable.

## Architecture

- `remote.sh guard <card> <provider-time>`: READ-ONLY (exit 3, `writes: never`), STALE (exit 1, the
  provider's time differs from the card's), PROPOSE (`writes: propose`, or `free` in a scope wider than
  project), OK.
- `remote.sh repoint <card> <id> <url> <type> <time>`: after converting an Office file; new id, link,
  type and time, `converted-from:`, Office extension dropped from the name, local copy renamed with it.
- How-to *Writing to a remote file*: the guard, a per-connector table (Docs `requiredRevisionId`; Sheets
  unguarded, prefer `append_values`; Slides untested), converting, never trashing without asking.

## Implementation (2026-11-16)

As designed. Plugin description now says Claude may read, write or keep decisions per folder (synced to
the marketplace, version unchanged). Suite 141 green on host and `bash:5` + git; 136 + 3 skipped in plain
`bash:5` and without HOME.

Left open: **Slides is untested** with the connector (none attached to this session). The how-to treats
it as unguarded until someone tests it; worth a short test when a Slides connector is available.

## Current State

Completed 2026-11-16. Next in the epic: PLUG-148.
