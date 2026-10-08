---
title: kickoff — interview to charter (plugin skeleton, sections A–F)
status: completed
type: feature
epic: kickoff
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | |
| 20 | Requirements | done | |
| 30 | Assessment | done | |
| 40 | Architecture | done | |
| 50 | Tests | done | |
| 60 | Implementation | done | |
| 70 | Tech Debt | done | none |
| 80 | Reflection | done | |

## Goal

The first vertical slice. The kickoff skill runs questionnaire sections A–F one section at a time, with
"accept all defaults" or change some. It writes the answers file and `docs/project/charter.md`, which
holds what the project is, the goal, the gate, scope, non-goals, a numbered decisions table with a why
for each, and the open questions.

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034.

## Acceptance criteria

- Plugin skeleton: `kickoff/.claude-plugin/plugin.json`, a marketplace entry, and a row in the repo
  CLAUDE.md Plugins table. Trigger words do not clash with the other plugins.
- Branching works: a question whose *Ask when* is false is skipped. A3 and A4 change the defaults.
- "Not decided yet" lands under Open questions, never as a guessed decision.
- The charter is generated from the answers file by a script, and that script has tests. Replaying the
  sample-poc answers yields its decisions D1–D5 and D7.
- Re-running with unchanged answers changes nothing (diff-guarded write).

## Dependencies

None. This slice owns the hot spots `plugin.json`, `marketplace.json` and `SKILL.md` first.

## Context

- **Spec:** `kickoff/skills/kickoff/references/questionnaire.md`, agreed 2026-10-08. Siblings PLUG-036..039 are all proposed; this task owns the skeleton.
- **Patterns to match:** task-roadmap, the smallest plugin. That means `scripts/lib.sh` for helpers (never sourced across plugins), `scripts/test/*.test.sh` with a `check` helper and `mktemp -d` fixtures, `json_str` ending in `|| true`, and writes made with temp file + mv behind a diff guard.
- **Tests run** in `bash:5` (docker), and on the host as the repo CLAUDE.md prescribes (bash 3.2 + BSD).
- **Collisions:** the crew session (claude-plugins-ee) owns `crew/`. marketplace.json was released to us at 4556ddd. Planning was committed at 8d3c413.
- **Finding, D1:** sample-poc's D1 (laptop + Docker) is a global rule, so it is never asked. The replay criterion is therefore D2–D5 and D7, plus D1 carried by the global CLAUDE.md.

## Requirements

- R1 The questionnaire is the single source: the scripts parse its tables. No second copy of the questions.
- R2 `plan.sh` lists every question with its state (ask / judge / skip / answered) and its resolved default, evaluating *Ask when* and `(★ if …)` against the answers so far.
- R3 `answer.sh` records an answer (`ID: value`, repeatable for lists with `--add`, `ID.why:` for the reason). The write is atomic and diff-guarded.
- R4 `charter.sh` generates `docs/project/charter.md` from the answers. An absent charter is written; an identical one is left untouched; a differing one is refused (exit 3) unless `--force`.
- R5 "Not decided yet" answers go to Open questions, never into the decisions table.

## Architecture

- **Answers file:** `<root>/.kickoff-answers`, plain `ID: value` lines with `#` comments, kept in the repo. It is the record of the kickoff: PLUG-039 diffs against it and PLUG-036 reads it.
- **Condition grammar** is documented in the questionnaire, §Reading the tables. Condition values are matched by case-insensitive prefix. Unknown wording means "judge", and Claude decides whether to ask.
- `lib.sh` holds `questions_tsv` (awk over the questionnaire: section, id, question, options, when, goes), `answers_get`, `cond_eval`, `default_for`, and `write_if_changed`.
- The skill's SKILL.md drives the loop: plan → ask one section → record answers → … → review screen → charter.
- Plan mode was not entered: the user asked for autonomous work and set the goal explicitly.

## Tests

`kickoff/scripts/test/kickoff.test.sh`, 59 checks, green on the host (bash 3.2 + BSD awk) and in `bash:5` (busybox awk), and from a copy of the plugin with no siblings. Coverage: branching and the conditional defaults, `pending` / `judge` / `stale` / `n/a`, answer writes (replace / `--add` / `--clear`, literal values, refusals, no rewrite when unchanged), and the charter (routing, open questions, escaping, the created / unchanged / refused / `--force` cycle). The sample-poc replay is the E2E success path for the scripted part.

**Shown failing:** turning `≠` into `=` in `lib.awk` makes 11 named checks fail (3b, 3e, 3f, 4a–4e, 7f, 7h, 8b).

## Implementation

- `kickoff/` with plugin.json 0.1.0, `skills/kickoff/SKILL.md` (the interview loop), `scripts/{lib.awk,lib.sh,plan.*,answer.sh,charter.*}`, README and CLAUDE.md. Added to the marketplace, the repo CLAUDE.md (tree, Plugins table, trigger vocabulary) and the README.
- **Questionnaire:** the content is unchanged. Its form is now machine-readable: formal conditions, `(★ if …)` defaults, a new §Reading the tables, and `n/a`. C1 now goes to `charter §Scope` and A3 to `charter`.
- **Bugs found by the test targets:** a `§` half-character under busybox, and `D0` from evaluation order on BSD awk. Both are fixed and recorded in the repo CLAUDE.md Shell Conventions.

## Tech Debt

None created. `defaults_tsv` in `lib.sh` is a deliberate stub for PLUG-038.

## Reflection

Repo CLAUDE.md: awk portability traps (Shell Conventions); the kickoff trigger words. Plugin knowledge is in `kickoff/CLAUDE.md`.

## Current State

Completed. Next: PLUG-037 (port registry).
