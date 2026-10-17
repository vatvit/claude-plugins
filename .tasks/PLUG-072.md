---
title: kickoff — answer the questionnaire from an existing project, ask only the rest
status: proposed
type: feature
epic: legacy-onboarding
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

kickoff's existing-project mode (PLUG-039) proposes answers only for questions a script can read from
files — about 14 of 46. On a legacy project most of the rest is answered too, in the README, the
manifests, the CI config, the Dockerfiles, the code and the `docs/` tree. Extend the mode so that
**most questions come pre-answered with evidence**, and the user is asked only what the project cannot
tell.

## Requirements (negotiable)

1. **More script hints** in `inspect.sh` where a file fact settles it: languages and frameworks from
   manifests (`package.json`, `composer.json`, `go.mod`, `pyproject.toml`, `Gemfile`, …), Docker/compose,
   CI provider, test framework, license, deploy files. Still read-only, still no git binary.
2. **A judged pass by Claude** for the prose questions (goal, one-liner, users, non-goals, constraints…):
   read README, `docs/` (when present — e.g. after docs-manager's PLUG-071) and the code, and propose an
   answer with the file and line it came from. Same rule as today: an inference is never an answer until
   the user confirms it; computed defaults stay refused by `answer.sh`.
3. **One confirmation table** for both passes (`id · proposal · evidence · script|judged`), confirm all
   or change some; then the usual loop asks only what is still open.
4. **Charter for an existing project** reads like the decisions were made at the start, but marks which
   ones were recovered from evidence vs decided now. scaffold keeps never touching existing files.

## Acceptance criteria

- On a generated fixture legacy project, `inspect.sh` proposes every question its new hints cover, each
  with evidence, and a question already in `.kickoff-answers` is never re-proposed.
- `plan.sh --next` after confirming lists only the questions with no proposal.
- Tests go through the real `questionnaire.md`; no question or option text is copied into a fixture.
- Suite green on host and `bash:5`, and from a copy of `kickoff/` alone (no docs-manager present).

## Notes

- Measure the gain: count of proposed questions before (today ~14) and after on the same fixture, and
  record it in the task when done.
- Invoked as `/kickoff:kickoff init`: SKILL.md gains a "Commands" section routing the `init` argument
  to this flow (the skill reads no arguments today). The `description:` triggers keep "run kickoff on
  this existing project" and add legacy wording, never bare *init* (built-in `/init`).
- Files: `kickoff/scripts/inspect.sh`, `infer.awk`, `skills/kickoff/SKILL.md` (step 0),
  maybe `charter.awk`, `scripts/test/`. Disjoint from PLUG-071. Overlaps the kickoff hot spots that
  PLUG-049's sub-tasks touch (`SKILL.md`, `questionnaire.md`) — check crew holds before starting.

## Current State

Proposed 2026-10-17 (epic PLUG-070). Not started.
