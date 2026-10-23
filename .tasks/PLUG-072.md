---
title: kickoff — answer the questionnaire from an existing project, ask only the rest
status: completed
type: feature
epic: legacy-onboarding
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | below |
| 20 | Requirements | done | the four in the task, plus 5 (close the gaps), added by the user 2026-10-23 |
| 30 | Assessment | done | inspect.sh/infer.awk extend cleanly; .why shows how to carry provenance; charter.awk routes |
| 40 | POC | skipped | no risky unknown; the reflog format was checked by hand |
| 50 | Domain | skipped | bash plugin, no domain model |
| 60 | Architecture | done | below (Decisions) |
| 70 | Tests | done | existing.test.sh: 6a-6r, 7a-7g, 8a-8j |
| 80 | Subtasks | skipped | one plugin, one change |
| 90 | Implementation | done | inspect.sh, infer.awk, gaps.sh, settled.awk, answer.sh, lib.awk, charter.awk, SKILL.md, questionnaire, README, manifests; 0.7.0 -> 0.8.0 |
| 100 | Tech Debt | done | none taken: the checks gaps.sh cannot see are the judged half by design |
| 110 | Reflection | done | plugin CLAUDE.md (don't-regress: first hint wins, .from, gaps.sh, set -e / BSD sed traps), root CLAUDE.md vocabulary |

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
- Belongs here (from PLUG-052): **skip the K1 docs skeleton when `docs/` predates kickoff** (PLUG-070
  decision: docs-manager owns `docs/` layout). "docs/ exists" is not the test — `charter.sh` creates
  `docs/project/` before `scaffold.sh` runs — so define "predates" (e.g. anything under `docs/` other
  than the charter and kickoff's own `_index.md` files).
- kickoff 0.6.0 (PLUG-049) added C5 with the `explicitly` state; an `inspect.sh` proposal for an
  explicit question is still only a proposal, the user picks.

## Context

- Epic PLUG-070. Since this task was written, PLUG-078 (kickoff 0.7.0) removed K1 (docs skeleton) and
  C3, renumbered ids, and made `docs/` docs-manager's: kickoff writes only `docs/project/`. So the
  "skip K1 when docs/ predates kickoff" note is **already done** by PLUG-078; nothing left here.
- Measured on the old ids: the existing-project mode hinted 13 questions in total (A0 A1 A5 R1 R4 R5 R6
  R7 R8 R11 I0 I2 I6), but only what a project actually has; on a typical legacy app fixture, 6.
- `kickoff/CLAUDE.md` "Don't regress" is the list to respect: no option wording in scripts, inspect.sh
  writes nothing and needs no git binary, `starts_ci` on whole strings, settled answers only.
- Vocabulary (repo CLAUDE.md): docs-manager owns *onboard / survey / legacy project*; kickoff keeps
  *existing project* and adds *close the gaps*. Neither puts a bare *init* in its triggers.

## Requirement added 2026-10-23 (the user)

> after the survey Claude will try to apply absent tools, docs, etc. or adjust the project accordingly
> to the answers. Claude may decide to ask the user — it is OK too. What I don't want: after survey
> Claude documents answers in some format and… nothing.

5. **Close the gaps.** After the charter and scaffold, list what the answers say the project has and it
   does not; for each, the user picks do it now (done and verified), make it a task, or leave it. A
   second run lists only what was left or made a task.

## Decisions

- **More script hints, same mechanism:** manifests (A2 description, A3 library/plugin markers, I4 stack
  `language — frameworks`, F12 test/lint tools), the reflog for R2 (git writes each commit subject to
  `.git/logs/HEAD`; ≥5 commits, ≥80% conventional or ≤20%), compose images for I3/I5, nvidia for I7,
  deploy files for I1, serverless for I2, locales for D3, more R4 entry points. **The first hint per id
  wins** (infer.awk), so stronger evidence is hinted first.
- **The judged pass is Claude's, in SKILL.md step 0**, with file-and-line evidence, merged with the script
  rows in one table (`script | judged`). No evidence, no row.
- **Provenance = `<ID>.from`**, written by answer.sh like `.why`; the charter marks those answers
  *recovered* (overview, A2, the Why column of decisions) and explains the mark once. No new file.
- **Close the gaps = `gaps.sh` (read-only, mechanical) + SKILL step 7 (judged gaps, one table, three
  choices, verify the fix).** The script checks what a file shows: R4 entry point, I0 containers, R6
  task setup, F2 Unit/E2E, F7 pre-commit/CI, each F12 tool in a manifest/config/script/CI file (never
  prose), the quality doc, CLAUDE.md, and `docs/` only when docs-manager is installed. Fixes are
  Claude's, since they depend on the stack and kickoff names none.
- **docs-manager first** when installed (SKILL step 0), so the judged pass reads the onboarded `docs/`.
- **`init` argument** routes to the existing-project flow; no bare *init* trigger.

## Results

- Proposals on the same legacy fixture: **6 before, 16 after** (A0 A1 A5 I0 I2 I6 → + A2 R2 I4 F12 D3 I1
  R4 I3 I5 I7). On this repo, read-only: 9, R2 and A3 new and correct.
- kickoff suite: 270 pass on host and in `bash:5` (existing 66, was 31); from a copy of `kickoff/` alone.
- Seen red: 6l/6m with the first-hint rule removed; 7d with the recovered mark removed; 8a with the
  entry-point check removed. Host-only failures found and fixed on the way: `set -e` killing inspect.sh
  on a missed grep in `$( )`, BSD sed `[ \t]` cutting `vitest` to `vites`.

- **Unexplained one-off:** one standalone run showed `ports.test.sh` 23/26 (3 failed); not reproduced in
  6 later runs (host, `bash:5`, standalone), and ports.sh is untouched by this task. If it recurs, it
  is worth a task of its own.

## Current State

Implemented 2026-10-23: kickoff 0.8.0, all steps done; not committed (awaiting the user).
