---
title: "session-storage plugin in Cowork"
status: completed
type: feature
priority: medium
epic: cowork
depends-on: [PLUG-111]
created: 2026-11-11 18:05
tags: ["session-storage-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | keeps nothing in HOME (tmp dir); the real gap: set printed "Stored" after a failed write; no tests at all |
| 20 | Requirements | skipped | the epic: exempt, plain message only |
| 30 | Assessment | done | also found jq, stat order, path checks → PLUG-132 |
| 40 | POC | skipped | nothing risky |
| 60 | Architecture | done | set fails with one plain sentence when the write fails |
| 70 | Tests | done | first suite, scripts/test/storage.test.sh (10 cases); red with the old storage.sh |
| 90 | Implementation | done | storage.sh cannot_write |
| 100 | Tech Debt | done | PLUG-132 (jq, stat order, unchecked path parts, hooks untested) |
| 110 | Reflection | done | session-storage/CLAUDE.md: Testing section |

## Description

Placeholder. It gets its detail from PLUG-111's findings. Goal and decisions are in the `cowork` epic.

Plugin(s): session-storage. Known touch points (grep, 2026-11-11; verify at Context): No `~/.claude` reference was found in its scripts. Find where storage.sh keeps data, and whether the SessionStart hook that hands out the session id runs in Cowork.

## Acceptance criteria (common to every sub-task of the epic)

- In Cowork, every user-visible capability of the plugin either works or says plainly that it is not available in Cowork and does nothing else.
- Outside Cowork nothing changes: the existing suite passes unchanged, and a test proves the Cowork branch is not taken on the CLI.
- The Cowork branch is covered by tests that simulate the detection signal found in PLUG-111.
- The plugin carries its own detection (Plugin Independence). Only the signal it checks is shared knowledge, kept in the doc that PLUG-111 writes.

## Current State

2026-11-11 19:05. Every step is done. storage.test.sh 10/10 on the host and in bash:5. A patch version bump is pending, done with the epic's other bumps.
## Update 2026-11-11 (epic round 2)

**Exempt from the project-folder-only requirement** (user): this plugin is host-bound by design. Left open: whether to
reject this task, or keep it for one small thing, a plain message when HOME (or launchd, or hooks) is unavailable instead of an obscure failure.
