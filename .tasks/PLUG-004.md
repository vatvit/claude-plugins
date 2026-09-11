---
title: Staleness — watch, stamp, check, bless, and the nudge hook
status: proposed
type: feature
priority: medium
epic: diagram-support
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | — | |
| 20 | Assessment | — | |
| 30 | POC | — | |
| 40 | Domain | — | |
| 50 | Architecture | — | |
| 60 | Tests | — | |
| 70 | Subtasks | — | |
| 80 | Implementation | — | |
| 90 | Tech Debt | — | |
| 100 | Reflection | — | |

## Description

The half that makes diagrams stay honest: a source declares what it depicts, and the
tool flags it as *suspect* when that changes. Includes the PostToolUse hook that
warns mid-session, while the change is fresh — the only moment a diagram actually
gets fixed.

**Full spec in PLUG-001** (R12–R16; Domain invariants "stale is a property of a
source" and "blessing is a human act"; Architecture D2/D5; Tests cases 10–17).

## Scope

- `watch:` — directory prefixes (trailing `/`) and exact paths, **no globs** (D2)
- `cksum` fingerprint over sorted path+content, so a rename counts (D5)
- `docs.sh diagram check` / `docs.sh diagram bless <name>`
- stale notice inside every embed's block
- `docs-manager/hooks/hooks.json` + hook script, modelled on `task-roadmap`'s
- hook always exits 0, never blocks a tool call

## Depends on

PLUG-002 (needs `fm_parse` and the block).
Independent of the refs and rendering slices.

## Acceptance

Cases 10–17 pass on both targets. Nothing but `bless` may ever write `stamp:`.
