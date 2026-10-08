---
title: kickoff — machine-wide port registry
status: proposed
type: feature
epic: kickoff
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

## Goal

A registry of every project's dev ports at `~/.claude/kickoff/ports.json`, machine-wide, which
deliberately ignores `CLAUDE_CONFIG_DIR` (repo CLAUDE.md, "Per account or per machine"). Commands:
allocate the next free port for a project, and list. When the registry does not exist yet, fall back to
scanning the compose files of existing projects. Seed it with the ports already in use (listed today
in project-e's CLAUDE.md).

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034. (section "Where kickoff keeps its own data", question I5)

## Acceptance criteria

- Two allocations never return the same port, even from two accounts with different
  `CLAUDE_CONFIG_DIR` values. A test proves it.
- Concurrent allocation is safe (lock, then write via a temp file and mv).
- Bash 3.2, BSD and GNU, no runtime. Tests run in Docker and from a copy of the plugin with no siblings.

## Dependencies

None. It has its own script and tests, so it can run in parallel with PLUG-035. It does not touch
`plugin.json`, `marketplace.json` or `SKILL.md`; the landing of PLUG-035 wires it in.

## Current State

Not started.
