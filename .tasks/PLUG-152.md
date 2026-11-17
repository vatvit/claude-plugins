---
title: "docs-manager: a PDF built from a markdown doc beside it is output, not an external doc"
status: proposed
type: bug
priority: medium
tags: ["docs-manager-plugin"]
created: 2026-11-17 13:24
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

`docs.sh check` fails with `NO CARD` on `guide.pdf` when `guide.md` sits beside it and the PDF is
built from it. The index also lists it under *External documents* with "no card yet". docs-manager
already ignores a `.pdf` rendered from a diagram source beside it (README, *Recognised extensions*);
a PDF rendered from a markdown doc is the same kind of output. Writing a card for it would duplicate
the doc. Found in PLUG-151 (`docs/guides/uk/*.pdf`, built by `docs/guides/build.sh`).

## Acceptance Criteria

- `X.pdf` beside a markdown doc `X.md` is output: no `NO CARD`, not listed as an external document.
- The index may list it beside its doc (e.g. "PDF") or not at all: decide at architecture.
- A `.pdf` without a same-named `.md` beside it still needs a card.
- Test seen red before the fix; host and container suites green.

## Current State

Proposed. Until it ships, `docs.sh check` in this repo reports `NO CARD` for the PLUG-151 guide PDFs.
