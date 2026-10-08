---
title: crew — user config must honour CLAUDE_CONFIG_DIR
status: proposed
type: bugfix
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | Architecture | — | |
| 50 | Tests | — | |
| 60 | Implementation | — | |
| 70 | Tech Debt | — | |
| 80 | Reflection | — | |

## Problem

`crew/scripts/lib.sh:13` hardcodes the per-account user layer:
`CREW_USER_CONFIG="${CREW_USER_CONFIG:-$HOME/.claude/crew.json}"`.
Under a second Claude account (Claude Code sets `CLAUDE_CONFIG_DIR`) that account silently reads the
first account's crew settings.

The repo rule (CLAUDE.md §Config convention, "Per account or per machine") says per-account data lives
in `${CLAUDE_CONFIG_DIR:-~/.claude}`, while machine-wide state lives in `~/.claude/<plugin>/`.
`CREW_HOME` (the session-name registry) is machine-wide and must stay as it is.

## Acceptance criteria

- With `CLAUDE_CONFIG_DIR` set to a non-default dir, crew reads its user layer from
  `$CLAUDE_CONFIG_DIR/crew.json`; unset, from `~/.claude/crew.json`. An explicit `CREW_USER_CONFIG` still wins.
- `CREW_HOME` keeps ignoring `CLAUDE_CONFIG_DIR` — a test asserts that, with the reason.
- crew README / CLAUDE.md say which crew files are per account and which are per machine.
- Version bump in `crew/.claude-plugin/plugin.json` and the marketplace entry.

## Current State

Not started. Found while designing kickoff's data locations.
