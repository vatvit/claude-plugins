---
title: "task — a .task-config.json written on one line is misread (tasksDir swallows the whole line)"
status: proposed
type: bugfix
priority: low
created: 2026-11-11 18:41
tags: ["task-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 30 | Assessment | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

Found while probing PLUG-118 (2026-11-11). `resolve-config.sh` parses the project config one key per line (awk, around lines 30-50).
A valid JSON object on a single line, `{"tasksDir":".tasks","prefix":"T","nextId":1}`, gives
`tasksDir=<dir>/.tasks","prefix":"T","nextId`, and `allocate-id.sh` then fails with `ERROR: config missing tasksDir/prefix`.
The multi-line form, the one the skill writes, works. Check whether the other scripts that write `nextId` back assume one key per line too.

Fix options: accept any JSON layout (tokenise on `,` and `{}` outside strings), or document one key per line as required and fail
with that message instead of a wrong value. Reproduce with a failing test first.

## Current State

Created 2026-11-11. Not started.

## Note 2026-11-11 (from PLUG-118)

`resolve-config.sh` has two copies of the key/value awk extraction: one for the local config (around lines 32-51) and one inside
`lookup_global` (around lines 91-108). Fix the one-line bug in a single shared awk function used by both, not twice.
