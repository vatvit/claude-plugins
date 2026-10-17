---
title: kickoff — next release backlog
status: completed
type: epic
epic-name: kickoff-next
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | per sub-task |
| 30 | Assessment | done |  |
| 40 | POC | skipped |  |
| 50 | Domain | skipped |  |
| 60 | Architecture | done | per sub-task |
| 70 | Tests | done | per sub-task |
| 80 | Subtasks | done | PLUG-050..052 |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | release synced |
## Goal

Collect the improvements for the next kickoff release in one place, and ship them together as **one**
version bump instead of one bump per improvement.

## Why

kickoff 0.5.0 (epic PLUG-034) is complete. New requirements keep arriving from the user. Implementing and
releasing each one alone would churn `plugin.json`, `marketplace.json` and `SKILL.md`, the plugin's
hot spots, once per change.

## Scope

- New or changed questionnaire questions.
- Making what kickoff generates (workflow, docs skeleton, CLAUDE.md, charter) apply the user's
  engineering principles, rather than restating them.
- One release at the end: the version bump, the description, keywords and trigger phrases, done once
  (repo CLAUDE.md, "Changing an Existing Plugin").

## Out of Scope

- **Restating global rules in project files.** Decided 2026-10-09: kickoff applies the principles in
  its output and never copies them into the project CLAUDE.md.
- **How Claude reports to the user** (screenshots used sparingly, full absolute paths in console
  output). Decided 2026-10-09: these go in the user's global CLAUDE.md only, so no kickoff change.

## Success Criteria

- Every sub-task is completed, with its tests green on both targets (host and `bash:5` container),
  and from a copy of the plugin that has no siblings.
- One version bump covers all of them, with `plugin.json`, `marketplace.json` and `SKILL.md` in sync.

## Release

Do this last, after every sub-task: bump `kickoff/.claude-plugin/plugin.json` (0.5.0 → 0.6.0),
sync `marketplace.json`, refresh the SKILL.md description, and check the trigger phrases against the
other plugins' vocabularies. Sub-tasks do **not** bump the version themselves.

## Sub-tasks

- PLUG-050: backward-compatibility question, asked explicitly
- PLUG-051: seeded workflow applies SOLID, DRY and INVEST
- PLUG-052: docs skeleton carries the SOLID/DRY docs conventions

## Outcome (2026-10-17)

- Released as **kickoff 0.5.1 → 0.6.0** (the epic text said 0.5.0; 0.5.1 shipped in between) and
  **docs-manager 1.7.1 → 1.8.0** (PLUG-052's convention). plugin.json, marketplace.json, SKILL.md
  version, READMEs (plugin and root) in sync. No new trigger phrases for kickoff (no new user verbs).

## Current State

Completed 2026-10-17. Host, `bash:5` container and a sibling-free copy: ALL GREEN. (kickoff and docs-manager suites)
