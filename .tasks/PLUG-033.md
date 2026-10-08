---
title: crew — user config must honour CLAUDE_CONFIG_DIR
status: completed
type: bugfix
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | filed by the kickoff session (claude-plugins-ef); rule in repo CLAUDE.md "Per account or per machine" |
| 20 | Requirements | skipped | ACs in the task are exact |
| 30 | Assessment | done | one line in crew/scripts/lib.sh; CREW_HOME already machine-wide |
| 40 | Architecture | done | user layer per account, name registry per machine — see Implementation |
| 50 | Tests | done | core.test.sh "per account vs per machine" (4 checks) |
| 60 | Implementation | done | 261/261 host + docker |
| 70 | Tech Debt | done | none filed |
| 80 | Reflection | done | crew README/CLAUDE.md/config.md say which files are per account vs per machine; 1.0.1 |

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

## Implementation

`crew/scripts/lib.sh`: `CREW_USER_CONFIG` defaults to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crew.json`
(an explicit `CREW_USER_CONFIG` still wins); `CREW_HOME` stays `$HOME/.claude/crew` with a comment
giving the reason (SendMessage spans accounts, so one registry per machine). `core.test.sh` asserts
all three cases plus CREW_HOME ignoring CLAUDE_CONFIG_DIR. Full run 261/261 on host and in `crew-test`.

## Reflection

crew `README.md` (Config: per account / per machine / per repo), `CLAUDE.md` design rule,
`references/config.md` user-layer path. Plugin 1.0.1.

## Current State

Completed. Build green; landed as crew 1.0.1.
