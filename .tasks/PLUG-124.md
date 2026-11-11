---
title: "This repo's .tasks/ workflow usable from Cowork (global step files)"
status: completed
type: feature
priority: low
epic: cowork
created: 2026-11-11 18:05
tags: ["task-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | only 2 global step files (context, reflection); WORKFLOW.md already says "deliberately not copied" |
| 20 | Requirements | skipped | — |
| 30 | Assessment | done | PLUG-118 decided against shipping default steps |
| 40 | POC | skipped | — |
| 60 | Architecture | done | accept the one-liners without HOME; do not vendor (second source of truth, in a public repo) |
| 70 | Tests | skipped | no code; PLUG-118 tests cover the task plugin running from the one-liners without HOME |
| 90 | Implementation | done | a 3-line note in .tasks/_workflow/WORKFLOW.md |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | the decision lives in WORKFLOW.md, where a session reads it |

## Description

`.tasks/_workflow/WORKFLOW.md` resolves step definitions from `.tasks/_workflow/steps/` first and then falls back to the global `~/.claude/project-tasks/_workflow/steps/`. They were deliberately never copied into the repo. In Cowork the global files are missing, so a session there has a step list but no step definitions.

Options to weigh: vendor the step files into `.tasks/_workflow/steps/` (which duplicates the global source of truth, so it needs a sync story), or accept that steps run from their one-line summaries in Cowork. This is a maintainer convenience, not plugin behaviour.

Independent of PLUG-111. It can start any time.

## Current State

Created 2026-11-11 as a placeholder.

## Update 2026-11-11

Overlaps PLUG-118, which decides where the task plugin finds step definitions with no HOME. If the plugin ships
default steps, this task may need no work. Settle 118's Architecture first.

## Decision 2026-11-11

Not vendored. Without HOME, `context` and `reflection` run from their one-liners; recorded in `.tasks/_workflow/WORKFLOW.md`.
Reopen if someone actually works on this repo from a sandbox and misses the step definitions.
