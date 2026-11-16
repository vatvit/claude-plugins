---
title: "remote-docs: cards on Drive, shared with the team"
status: completed
type: feature
priority: medium
epic: remote-docs
deps: [PLUG-146, PLUG-147]
tags: ["remote-docs-plugin"]
created: 2026-11-16 14:55
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | epic Connector facts (Docs revision guard), PLUG-145/146 (.source.md, cards-at) |
| 20 | Requirements | done | ## Requirements |
| 30 | Assessment | done | ready: PLUG-147 landed (940235e) |
| 40 | POC | skipped | the guard is the tested Docs requiredRevisionId; the rest is offline text handling |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | CD1a–g, CD2a–c, CD3a–g, seen red (15 failing) first |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | remote-docs CLAUDE.md (Cards on Drive), how-to, README (plugin + root), SKILL, root vocabulary |

## Description

When the user chooses it for an attachment, the cards live on Drive so every teammate's Claude reads the
same map. Cards on Drive are edited by several sessions, so they go through the same stale-write guard. The
scripts work offline on local files: Claude pulls the cards into a temp listing for them. Consider one
card document per folder (one read per folder instead of one per file).

## Acceptance criteria

- Attach, refresh and check work with cards on Drive as with local ones.
- Two sessions updating cards never overwrite each other silently.

## Requirements

Acceptance criteria above, with the approved plan (2026-11-16): **one card document per attachment**
(one read per folder, one guarded write), holding the folder's `.source.md` files too, which is how the
purposes reach every teammate (PLUG-145's open question, second half).

## Architecture

- `remote.sh pack <dir>`: every `.source.md`, then every card, under `<!-- remote-docs: <path> -->`
  markers, in byte order; refuses a file holding a marker line.
- `remote.sh unpack <text> <dir>`: into an empty folder; every path checked first (relative, no `..`, a
  `.source.md` or a card); text before the first marker ignored.
- The local folder keeps `.source.md` with `cards-at: drive`, `cards-id`, `cards-url`.
- How-to *Cards on Drive*: pull (keep `revisionId`), unpack, work, pack, one guarded `update_doc`; on
  rejection pull again and re-apply.

## Implementation (2026-11-16)

As designed. Suite 158 green on host and `bash:5` + git; 153 + 3 skipped in plain `bash:5` and without
HOME.

## Current State

Completed 2026-11-16. Next in the epic: PLUG-149.
