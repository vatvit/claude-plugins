---
title: crew — machine-wide slots: a heavy run in one repo queues against another repo's
status: proposed
type: feature
epic: crew-solo
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

Slots live in `<git-common-dir>/crew`, so they only order runs inside one repo. The CPU, memory and Docker
they protect belong to the machine. Two crews in two repos on one Mac each grant a `cpu` slot at once and
slow each other down. Session names are already machine-wide (`~/.claude/crew/`), so slot state of the
machine kind fits the repo's "Per account or per machine" rule: it guards a machine resource, so it lives
in `~/.claude/crew/` and ignores `CLAUDE_CONFIG_DIR`.

## Requirements (negotiable)

- Machine-scoped queue for the classes that contend for the machine (`cpu`, `exclusive`; decide `quiet`
  at Architecture), or a separate cross-repo class. Settle which at Architecture.
- `slot` and `status` show a waiting request's blocker by session name **and repo**, with an ETA.
- Stale entries from a repo whose crew is gone are reaped, as per-repo slots are today.
- Open: does a **solo** session (repo with no crew) take part? Today "no crew, no cost" means its hooks do
  nothing. Probably an explicit `crew slot` call from a solo session still queues, with no hooks added.

## Acceptance criteria

- Two fixture repos, each with a crew: a `cpu` slot held in A makes a `cpu` request in B wait, and B's
  output names A's holder and an ETA. Releasing in A grants B.
- A repo-local class (if any remain) still does not block across repos.
- Machine-wide state lives under `~/.claude/crew/` (tests override HOME), never in a committed path.
- Suite green on host and `bash:5`, and from a copy of `crew/` alone.

## Notes

- Files: `crew/scripts/slot.sh`, `lib.sh`, `status.d/`, `scripts/test/`, skill reference on slots.

## Current State

Proposed 2026-10-17 (epic PLUG-073). Not started.
