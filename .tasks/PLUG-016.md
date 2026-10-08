---
title: docs-manager — catalogue external docs (pdf, docx, xlsx) for Claude
status: proposed
type: epic
epic-name: external-docs
priority: medium
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

## Goal

Users drop external reference files (pdf, docx, xlsx, …) into `docs/external/` (see Layout).
docs-manager catalogues each one so Claude knows **what it contains, when to read it, and
where exactly inside it to look** — and keeps project docs in sync with those sources.

## Design (agreed 2026-10-08)

- **Layout (decided 2026-10-08):** externals live in their own tree, `docs/external/`,
  apart from authored docs (authored = we edit; external = we replace, never edit).
  - Drop zone: the top level of `docs/external/`. A file there is "new" by definition; the
    ingest flow proposes a topic folder and files it as `docs/external/<topic>/`.
  - Detection is still by extension anywhere under `docs/` — an external file dropped
    elsewhere (e.g. `docs/architecture/`) is reported as new and ingest offers to move it
    into `docs/external/`.
  - Authored docs link *out* to cards (`../external/<topic>/x.pdf.md`); the binary is never
    moved next to authored text.
  - Root is one key in `.docs-manager.json` (e.g. `externalDir`), default `docs/external`.
- **Card per external file:** `<file>.<ext>.md` beside it, frontmatter `title`,
  `description`, `source`, `digest` (sha256 of bytes — never a path), `read-when`,
  `relates-to`; body `## Where to look` (pages / sheets+columns / headings → topic).
  Cards are ordinary docs, so the existing `docs.sh index` lists them unchanged.
- **Scripts do work, skill does judgement:** scripts detect/hash/move/index; Claude reads,
  summarises, proposes placement and doc updates — user confirms moves and edits.
- **Runtime-free:** pdf is read by Claude natively; docx/xlsx extraction only via tools
  already present (docker optional, needs user approval) — graceful fallback otherwise.
- **Single source of truth:** project docs link to cards and cite locations, never copy.
- **Binaries:** a file the user placed in the project explicitly is committed — the plugin
  never gitignores, LFS-routes or deletes it. Anything the plugin itself produces besides
  cards (extracted text, previews) goes to a temp dir, never into the repo.
- **Trigger vocabulary:** *external docs / ingest / catalogue / reference material* — avoid
  bare "pdf/excel/word", owned by the built-in document skills.

## Scope

Card format + index, staleness check, ingest flow, docx/xlsx extraction, related-doc flagging.

## Out of scope

Converting external files into native markdown docs; OCR of scanned PDFs; any network fetch.

## Success criteria

A mixed folder of pdf/docx/xlsx dropped into `docs/external/` ends up placed, carded, indexed, and
`docs.sh check` reports clean; changing one source flags its card and its related docs.

## Sub-tasks

- PLUG-017: card format + index integration
- PLUG-018: staleness check — new / changed / orphaned
- PLUG-019: ingest skill flow — read, card, place, move
- PLUG-020: docx/xlsx extraction with fallback
- PLUG-021: `relates-to` change flagging

Order: PLUG-017 first (defines the card); then PLUG-018 ‖ PLUG-019 in parallel (scripts vs skill text, disjoint
files); PLUG-020 and PLUG-021 after PLUG-019 / PLUG-018 respectively, and independent of each other.
