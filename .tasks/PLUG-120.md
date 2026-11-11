---
title: "delay plugin in Cowork"
status: completed
type: feature
priority: medium
epic: cowork
depends-on: [PLUG-111]
created: 2026-11-11 18:05
tags: ["delay-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | probe: HOME unset crashed every command (lib.sh:24); a not-writable HOME gave a raw mkdir error on add |
| 20 | Requirements | skipped | the epic: exempt, plain message only |
| 30 | Assessment | done | the only write path from the client is project_store (lib.sh) |
| 40 | POC | skipped | nothing risky |
| 60 | Architecture | done | DELAY_HOME empty without HOME; need_home in project_store refuses plainly; no fallback (host-bound) |
| 70 | Tests | done | delay.test.sh 23a–e: HOME unset and HOME a file; red with the old lib.sh |
| 90 | Implementation | done | lib.sh: DELAY_HOME ${HOME:+…}, need_home; delay/CLAUDE.md bullet |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | delay/CLAUDE.md: Host-bound bullet |

## Description

Placeholder. It gets its detail from PLUG-111's findings. Goal and decisions are in the `cowork` epic.

Plugin(s): delay. Known touch points (grep, 2026-11-11; verify at Context): The runner needs launchd and pmset on the host and runs jobs in docker. Most likely outcome: every delay command in Cowork says plainly that delay is not available there and queues nothing. `delay/scripts/lib.sh` (DELAY_HOME).

## Acceptance criteria (common to every sub-task of the epic)

- In Cowork, every user-visible capability of the plugin either works or says plainly that it is not available in Cowork and does nothing else.
- Outside Cowork nothing changes: the existing suite passes unchanged, and a test proves the Cowork branch is not taken on the CLI.
- The Cowork branch is covered by tests that simulate the detection signal found in PLUG-111.
- The plugin carries its own detection (Plugin Independence). Only the signal it checks is shared knowledge, kept in the doc that PLUG-111 writes.

## Current State

2026-11-11 18:59. Every step is done. delay suite 267/267 on the host and in bash:5. Version bump (patch) is pending; it is done with the other
epic bumps at the end. The reworded scope: no fallback location, only a plain refusal when HOME is not writable.
## Update 2026-11-11 (epic round 2)

**Exempt from the project-folder-only requirement** (user): this plugin is host-bound by design. Left open: whether to
reject this task, or keep it for one small thing, a plain message when HOME (or launchd, or hooks) is unavailable instead of an obscure failure.
