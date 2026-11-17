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

## Implementation — screenshots added (2026-11-17)

- The user supplied 13 Cowork screenshots → `docs/guides/uk/images/01-*.png` (9) and `02-*.png` (4).
- Part 1: install steps reworded to match the UI. Covers the Cowork toggle, Налаштування → Плагіни, «+ Додати» → URL + «Синхронізація»
  (trust warning, auto-sync toggle), «Огляд» → «+», Конектори → Google Drive → «Підключити до Claude» → browser «Продовжити
  підключення» → «Відкрити Claude.app», and «Додати папку». The marketplace appears in Cowork as «з джерела «claude-plugins»», not «vatvit-plugins».
- Part 2: the install step uses the plugin page («Додати»), with a note on the «claude-plugins» source label and the «може виконувати код
  без запиту дозволу» warning. The created-task slot became two images (create + `/task show`), and the list slot got its image.
- Dropped at the user's word: Part 1 card creation, first-attach questions and answer slots. Part 2 first-run questions slot.
- Build: `built` both, then `unchanged` on a second run; PDFs read back with images visible; `links` clean.

## Current State

All slots replaced; PDFs rebuilt. Not committed. Open: the screenshots show the user's own project folder name and test task titles.
