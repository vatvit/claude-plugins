---
title: docs-manager external docs — docx/xlsx extraction with fallback
status: proposed
type: feature
priority: medium
epic: external-docs
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

## Description

docx / xlsx (and doc / xls) cannot be read natively. Extract text / sheet structure using
tools only if present (e.g. pandoc, libreoffice, unzip+awk on OOXML), optionally in docker
with explicit user approval; otherwise fall back to a minimal card (`description` from the
user, `## Where to look` marked TODO). Never install anything.

## Acceptance criteria

1. Tool detection is one function; absence yields the fallback, not an error.
2. xlsx card lists sheet names and header columns; docx card lists headings.
3. Pure unzip+awk path for OOXML evaluated in POC — adopt if it covers 2 without extra tools.
4. Tests with tiny fixture files; host + container.
