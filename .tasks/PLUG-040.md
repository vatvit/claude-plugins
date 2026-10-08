---
title: crew — live smoke test of the hook contracts in Claude Code
status: proposed
type: chore
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

## Description

The crew suites prove everything except the two contracts with Claude Code itself:
- a PreToolUse hook's JSON `permissionDecision: "deny"` really blocks the tool call, and Claude
  reads the reason;
- SessionStart stdout really lands in context, including again after `/compact`.

Both are documented hook contracts, but nothing in the repo exercises them. They were not run
during the epic, because that needs the plugin installed in a live session, and installing
needs the user's go-ahead.

## Acceptance criteria

- [ ] With crew installed from the marketplace, two sessions in a scratch repo:
  - `whoami` binds without `--sid`;
  - SessionStart shows the crew lines after a restart and after `/compact`.
- [ ] `git add -A` is denied in the live session, with crew's reason shown to Claude.
- [ ] An Edit to a file the other session holds is denied, naming the holder.
- [ ] Record the Claude Code version checked in `crew/CLAUDE.md` § Testing.
