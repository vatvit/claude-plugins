---
title: "docs-manager and task-roadmap — confirm they work with the project folder only"
status: completed
type: feature
priority: medium
epic: cowork
created: 2026-11-11 18:05
tags: ["docs-manager-plugin", "task-roadmap-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | neither plugin reads HOME (grep, PLUG-111); hooks: one PostToolUse each |
| 20 | Requirements | skipped | the acceptance criteria are the requirements |
| 30 | Assessment | done | the suites never set HOME themselves, so a run without HOME is a real test |
| 40 | POC | skipped | nothing risky |
| 60 | Architecture | skipped | no code change |
| 70 | Tests | done | 5 suites × HOME normal/unset/missing/file in bash:5 + git: all green |
| 90 | Implementation | done | no code; a no-HOME container command and a note in each plugin CLAUDE.md |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | the rule is pinned where each plugin documents its tests |

## Description

Requirement and decisions: epic PLUG-117, *Decisions, round 2*. Facts about the environment: PLUG-111.
This task no longer waits for PLUG-111. The requirement does not depend on Cowork internals, so it can start now.

Neither reads `$HOME` or `~/.claude` (grep, PLUG-111 Context). task-roadmap reads `tasksDir` only from the project's `.task-config.json`.
Confirm by running both suites with HOME pointed at a missing dir. Expected outcome: no code change, possibly a test
that pins it.

## Acceptance criteria (common to the project-folder-only sub-tasks of the epic)

- **Project folder only:** with HOME unavailable (unset, missing or not writable) and only the project folder writable, every
  capability works. The exception is a capability the user explicitly chose to keep in HOME: it says plainly that it
  needs HOME and does nothing else.
- **HOME available:** existing behaviour and defaults are unchanged unless the epic says otherwise, and the existing suite passes.
- **Upgrade needs no action:** a user moving from the previous version keeps working with no migration step, no new prompt and no
  lost state. A test runs the new version against state written by the old one (a fixture copied from the current format).
  (Expected trivially: no code change.)
- Tests simulate project-folder-only by running with HOME pointed at a missing or read-only dir, in the Alpine container.
- Plugin Independence: the plugin carries its own fallback logic. No code is shared with another plugin.

## Current State

2026-11-11 18:48. Every step is done. Result: docs-manager (docs 38, diagram 100, external 155, onboard 34) and task-roadmap (30)
pass with HOME unset, missing, or pointing at a file (bash:5 + git). No code change, so no version bump. Their CLAUDE.md
files each gained a no-HOME container command. Note: docs-manager has unrelated uncommitted work from another session (external.sh).
