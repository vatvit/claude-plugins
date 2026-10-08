---
title: docs-manager external docs — ingest flow: read, card, place, move
status: completed
type: feature
priority: medium
epic: external-docs
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-017 Context applies; vocab checked — see Context |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | the procedure is prose (judgement); only `move` is a script |
| 40 | POC | done | walkthrough doubles as POC: native PDF read gives page numbers |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | M1–M3 in `external.test.sh` + walkthrough |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 42/42 + 100/100, host + bash:5; walkthrough clean |
| 100 | Tech Debt | done | `relates-to` unvalidated — already PLUG-021's scope |
| 110 | Reflection | done | reference, SKILL.md triggers, repo CLAUDE.md vocab |

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

## Context

Same session as PLUG-017/018. Trigger vocabulary: no other plugin's skill description uses
*catalogue / ingest / reference material / external*; docs-manager now owns those, and the repo
`CLAUDE.md` records that bare *pdf / word / excel / docx / xlsx* belong to Claude's built-in
document skills, which no plugin here may claim.

## Architecture

- **Procedure is prose, in one home:** `references/how-to-external-docs.md` §"Cataloguing — the
  procedure" (7 steps: status → read → card → propose placement → move → stamp → index/check →
  offer doc updates) and §"Answering from an external file". SKILL.md only points at it.
- **Unreadable formats get an honest minimal card, left unstamped**, so `check` keeps reporting it
  instead of vouching for a card nobody checked. PLUG-020 replaces this with extraction.
- **Large files → sub-agent** drafts the card, so file content stays out of the main context.
- `external move <file-or-card> <dest-dir> [root]`: refuses to overwrite either target (including a
  stale card already at the destination — never adopt one); if the card's move fails the file is
  moved back, so the two are never apart; reports links that name the moved file or originate in
  the moved card; never rewrites links.

## Implementation

- `external.sh` `cmd_external_move` (rollback + `has_card` flag), tests M1–M3.
- SKILL.md `description:` trigger phrases; repo `CLAUDE.md` vocabulary line.
- **Walkthrough (AC 3)**, in the session scratchpad, not the repo: two generated multi-page PDFs
  (`acme-payments-api.pdf`, 3 pp.; `data-retention-policy.pdf`, 2 pp.) dropped in `docs/external/`.
  `status` → 2× `new unfiled`; read natively (page-accurate); cards written; moved to
  `external/acme-payments/` and `external/compliance/` — `move` reported the one authored link it
  broke, which was then fixed; stamped; `index --write` created topic indexes listing
  ``[`acme-payments-api.pdf`](acme-payments-api.pdf.md) — <description>``; TODO descriptions
  filled; `docs.sh check` → `docs check: OK`. The same tree (stamped on macOS with `shasum`) also
  checks clean in bash:5 (busybox `sha256sum`) — digests agree across tools.
- Placement approval in the walkthrough was given by me, in a throwaway sandbox; in a real project
  step 4 asks the user.

## Reflection

**Docs:** reference procedure + answering section; SKILL.md triggers; repo `CLAUDE.md` vocab.
**Lesson:** the tool shell is zsh — `$var` holding a command does not word-split and arrays
behave differently; run helper scripts as `bash file.sh`, never inline multi-function bash.
**Follow-ups:** none new — `relates-to` validation and change flagging are PLUG-021; docx/xlsx
reading is PLUG-020.

## Current State

Done; ACs 1–3 met. Not committed.
