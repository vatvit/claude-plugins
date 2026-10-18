---
title: kickoff — a generic questionnaire; quality level with per-aspect DROP/ADD; proposed options; sibling plugins asked only when installed
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | kickoff scripts, questionnaire and the sibling plugins' install record read |
| 20 | Requirements | done | questionnaire agreed with the user (draft promoted); acceptance criteria above |
| 30 | Assessment | done | changes in lib.awk/lib.sh + generators; no other plugin touched |
| 40 | POC | skipped | the emulated questionnaire runs in the conversation served as the proof |
| 50 | Domain | done | levels, aspects, DROP/ADD, proposed vs computed options — in questionnaire.md |
| 60 | Architecture | done | conditions stay in lib.awk only; quality.awk and workflow.awk as separate generators |
| 70 | Tests | done | 235 pass in bash:5; each new test seen failing under its defect |
| 80 | Subtasks | skipped | one coherent change to one plugin |
| 90 | Implementation | done | 0.7.0 |
| 100 | Tech Debt | done | none left; host-target run not done (no scripts on the host) |
| 110 | Reflection | done | plugin CLAUDE.md (don't-regress, test IFS trap), root CLAUDE.md vocabulary, READMEs, SKILL.md |

## Description

Kickoff is a process: collect what is known about a project, ask what is not, record the decisions.
It must work for any project, so every question and option becomes generic. The agreed design is
`kickoff/skills/kickoff/references/questionnaire-draft.md` (agreed with the user 2026-10-18, after an
emulated kickoff of an AI-model project); applying it replaces `questionnaire.md` and deletes the draft.

In short:
- No stack, vendor, engine, tool or domain named in a question or option: such values are *proposed*
  by Claude from earlier answers (B1, B6, C2, D2, E1, E2, I4, I5, F5, F12).
- No personal setup assumed: "global rules" become E4 "rules that differ here"; identity is A6, asked.
- Every question informs a nameable decision, or it is removed (B2, B4, C3, K1 removed).
- Section F: a quality level (None / Basic / Standard / Full) then per aspect one multi-select of
  DROP / ADD options; tools named for the stack; output `docs/project/quality.md`.
- Multi-select option labels start with what ticking does: DROP / ADD / OUT OF SCOPE / USES.
- Sibling plugins (crew, task, task-roadmap) are asked about only when installed; `docs/` layout is docs-manager's.
- Dependency order: a question waits while its condition or `(★ if …)` default depends on an unanswered one (A6 on A4).
- Answers cross-checked after each section and on the review screen.
- Section E before I; new I0 (dev environment), I7 (special compute), R6 (task tracking), R10 (practices).

## Acceptance criteria

- questionnaire.md is the draft (status agreed), the draft file is gone, no question has more than 4 options.
- lib.awk parses `and`, `<ID> has <opt>`, `<plugin> installed`; a question whose default depends on an
  unanswered question is pending.
- scaffold writes no docs skeleton; charter + quality.md come from the answers; CLAUDE.md lines follow the new ids.
- inspect.sh hints use the new ids and option wording.
- Tests cover each new condition, the pending default, quality.md, and plugin-gated questions; each seen red.
- Both targets green (host + bash:5 container).

## Current State

2026-10-18: implemented, not committed. Status and workflow rows untouched (no `/task do` was run).

- **Code:** questionnaire.md promoted (draft files deleted). lib.awk gains `and`, `has`, `<plugin> installed`,
  pending `(★ if …)` defaults and prefix-italic proposed options. lib.sh reads installed_plugins.json
  (`KICKOFF_PLUGINS` overrides). New quality.awk (docs/project/quality.md) and workflow.awk (R10 drops
  practices). scaffold.sh no longer writes a docs skeleton. claude.awk, charter.awk, plan.awk and
  inspect.sh follow the new IDs.
- **Tests:** 235 pass in `bash:5` (defaults 18, existing 31, kickoff 107, ports 26, scaffold 53). Every
  new test was seen failing under its defect: default_waits, `has`, `installed`, `and`, proposed
  refusal, install scope, R10, quality list, A6 identity. A helper bug was fixed: `IFS=$'\t' read`
  collapsed an empty value column. The host run was not done (no scripts on the host).
- **Docs:** SKILL.md, plugin CLAUDE.md and README, root README and CLAUDE.md (trigger vocabulary),
  plugin.json and marketplace.json are at 0.7.0.
- **Next:** the user reviews, then commits; optionally run the host target.

## Changes from the previous questionnaire

Kept here as history; the questionnaire itself holds only the current questions.

| Was | Now | Why |
|-----|-----|-----|
| A3 option *Game* | *Internal tool / automation*; the domain lives in A2 | A3 is how the project lives, not its domain |
| A4 note: identity rule | A6, asked | a personal rule becomes the user's choice |
| B1 fixed PoC sentence | proposed from A2, A3 | one user's wording |
| B3 → charter §Demo plan | §Milestones | not every project has a demo |
| B4 a review before it is shown | removed | no decision could be named that it informs |
| B2 who judges the result | removed | its only consumer was B4; no other decision could be named |
| B5 note *sample-poc* | generic | no project history in a public plugin |
| C1 ★ Minimal for every project | ★ Production-grade, Minimal for PoC | the PoC default only fits PoCs |
| C3 source material to bring in | removed | `docs/external/` is docs-manager's, and outside material comes with almost every project: the answer informs nothing |
| D1 asked when A3 ≠ Library | judgement: the project handles data; + *None* | |
| D2 one coherent "world", fixed | proposed | one past project's technique |
| D3 ★ English | ★ the language of this conversation | |
| X *Demo shortcuts* | *PoC shortcuts*, each also judged by what the project has | |
| — | I0 where it runs during development | containers were assumed |
| I2 *one container* / *compose* | one deployable / a few services / not deployed | containers were assumed |
| I3 *SQLite / PostgreSQL* | None / Files / A database / Several; engine proposed in I5 | named engines |
| I5 dev port | I6, asked when it serves on a port | |
| E1 *Uses an AI model?* ★ Yes, E2 *OpenAI · Anthropic · Azure* | E1 any external services, E2 provider proposed per service | AI was assumed; named vendors |
| E4 other services | merged into E1 | |
| E5 exceptions to *the global rules* | E4 rules that differ from how you usually work | assumed one user's rules |
| F1, F2 | §F rebuilt; old F2 is F11 | |
| R4 `docker compose` option | task runner, the stack's own tool | containers were assumed |
| R5, R9 asked always | asked when crew / task-roadmap is installed (R5, R11) | plugin independence |
| R6–R8 | R6 task tracking (generic), R7–R9 when the task plugin is installed | |
| — | R10 practices of the workflow | the seeded practices were not a choice |
| K1 docs skeleton | removed | the `docs/` layout is docs-manager's; kickoff writes only `docs/project/` |
| E after I | E before I | the stack (I4) depends on the external services (E1) |
| — | I7 special compute | GPUs, large memory or a cluster change the dev environment, hosting, stack and cost |
| — | dependency order and cross-checks of answers | found by an emulated kickoff: A6 recommended against an unanswered A4; E1 contradicted I5 |
| K2 ★ English | ★ the language of this conversation | |
| *Never ask about the global rules* (SKILL.md) | read the user's standing instructions; ask what they leave open | assumed one user's rules |
| scaffold: dev docs "all in Docker" | from I0 | containers were assumed |
