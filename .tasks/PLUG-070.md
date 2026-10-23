---
title: adopt a legacy project — docs and kickoff as if they had been there from the start
status: completed
type: epic
epic-name: legacy-onboarding
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | below |
| 20 | Requirements | done | open questions settled 2026-10-17; per-plugin requirements in PLUG-071/072 |
| 30 | Assessment | skipped | per sub-task: the two touch disjoint plugins |
| 40 | POC | skipped | no risky unknown at epic level |
| 50 | Domain | skipped | bash plugins, no domain model |
| 60 | Architecture | done | cross-plugin flow fixed in Scope/Out of Scope: no shared code, flow described in each SKILL.md |
| 70 | Tests | skipped | per sub-task |
| 80 | Subtasks | done | PLUG-071, PLUG-072 |
| 90 | Implementation | done | PLUG-071 (docs-manager 1.9.0), PLUG-072 (kickoff 0.8.0) |
| 100 | Tech Debt | done | PLUG-083 (docs-manager onboard shortcuts); none from PLUG-072 |
| 110 | Reflection | done | both plugin CLAUDE.md files, root CLAUDE.md trigger vocabulary, root README |

## Goal

Point docs-manager and kickoff at an **existing legacy project** and end with the state a project would
have had if both plugins had been used from day one: a `docs/` knowledgebase built from what the project
already holds, a `.kickoff-answers` file with most questions answered from evidence, and a charter.
The rest of the plugins (task, crew, task-roadmap, delay) then have their foundation.

## Why

Both plugins assume a project starts with them. Most real projects do not. Today:

- **docs-manager** maintains a docs set but has no way to *find* the docs a project already has
  (README, `doc/`, wiki exports, ADRs, scattered `*.md`, OpenAPI files, comments in config) and turn
  them into a `docs/` tree.
- **kickoff** has an existing-project mode (PLUG-039, `inspect.sh`), but it reads only file-level
  facts: it proposes about 14 of the 46 questions (A0, A1, A5, C3, I2, I5, K1, R1, R4–R7, R9). Goal,
  one-liner, stack, hosting, testing, constraints and the like are left for the user to type, though
  the project often answers them already.

## Scope

- PLUG-071: docs-manager — survey where the docs live now, propose a plan, build `docs/` from it.
- PLUG-072: kickoff — answer the questionnaire from the project (and from `docs/`, when present), ask
  only what is left.
- One user-facing flow when both are installed: docs-manager first, then kickoff reads the docs it
  produced. Each still works alone (repo CLAUDE.md, "Plugin Independence").

## Out of Scope

- A shared "init" script across the two plugins. They cannot source each other; the flow is described
  in each SKILL.md, not coded.
- Importing from external services (Confluence, Notion, Jira, wikis online). Exported files dropped
  into the project are in scope; fetching them is not (user rule: no external tools at runtime).
- Setting up task, crew, delay, task-roadmap. They read what this epic produces; their own setup stays
  theirs.

## Open questions (settle at Requirements)

- ~~**The word.**~~ Decided 2026-10-17: the action is an explicit skill argument,
  `/docs-manager:docs-manager init` and `/kickoff:kickoff init`. Neither SKILL.md reads arguments today;
  each gains a small "Commands" routing section (as the task skill has). The namespace keeps it clear of
  the built-in `/init`. What still holds: bare *init* never goes into a `description:` trigger list (that
  would compete with `/init` at auto-activation). Natural-language triggers use per-plugin words
  (e.g. *onboard a legacy project* / *survey the existing docs* for docs-manager, *existing project* for
  kickoff); *adopt* stays crew's. The repo CLAUDE.md line "never says *init*" was already refined
  this way on 2026-10-17 (epic PLUG-073's reflection).
- ~~**Who owns `docs/` layout.**~~ Decided 2026-10-17 (user agreed): docs-manager owns content and layout
  of `docs/`; kickoff writes only the charter and answers, and skips its K1 docs skeleton when `docs/`
  already exists. PLUG-052 (which changes that skeleton) must respect this. The epic split into
  PLUG-071/072 is also agreed.

## Context

**Since the epic was written (2026-10-17):**
- PLUG-078 (kickoff 0.7.0, completed) rewrote the questionnaire: K1 docs skeleton and C3 source material
  are **removed**, ids renumbered, scaffold writes no docs skeleton, `docs/` layout is docs-manager's and
  kickoff writes only `docs/project/` (charter, quality.md). So PLUG-072's "skip K1 when docs/ predates
  kickoff" note is already resolved, and its "14 of 46" count must be re-measured on the new ids.
- PLUG-049 and PLUG-052 are completed: no kickoff release to bundle with.
- PLUG-079 (docs-manager 1.8.1): every docs walk goes through `docs_find` in `docs-manager/scripts/lib.sh`;
  a survey of the whole project must not reuse it blindly (it walks `docs/`, not the project).

**Versions now:** docs-manager 1.8.1, kickoff 0.7.0.

**Parallel-session collisions:** crew lists `claude-plugins-kickoff` (worker) and `claude-plugins-delay`
(coordinator), both silent for ~2 weeks, no holds, tree clean. PLUG-071 touches only `docs-manager/`,
PLUG-072 only `kickoff/`.

## Success Criteria

- On a fixture legacy project (fake data, generated in tests — no real project named; the repo is
  public), docs-manager produces an approved plan and a `docs/` tree whose links check clean, and kickoff
  proposes clearly more answers than today, each with evidence.
- Nothing in the project is moved, deleted or overwritten without the user approving the plan.
- Each plugin's suite passes on host and in the `bash:5` container, and from a copy with no siblings.
- One version bump per plugin, with `plugin.json`, `marketplace.json`, `SKILL.md` and the root README in
  sync (repo CLAUDE.md, "Changing an Existing Plugin").

## Sub-tasks

- PLUG-071: docs-manager — survey existing docs and build `docs/` from them
- PLUG-072: kickoff — answer the questionnaire from the existing project

## Results

- **Scope grew on the way (the user, 2026-10-23):** onboarding must not end in documents. docs-manager's
  `onboard` already acts (moves, links, then Claude writes the missing docs); kickoff gained **close the
  gaps** (PLUG-072 requirement 5): `gaps.sh` + SKILL step 7, each gap done now and verified, made a
  task, or left by the user's choice.
- Success criteria: fake legacy fixtures generated in the tests (no real project named); docs-manager
  builds `docs/` whose `check` passes after Claude's follow-up, and a second survey is empty; kickoff
  proposes 16 instead of 6 answers on its fixture, each with evidence; nothing is moved before a plan is
  approved (S2, P4) and inspect/gaps write nothing (6n, 8h); both suites green on host, `bash:5` and
  from a standalone copy; one bump per plugin with plugin.json, marketplace.json, SKILL.md, root README.

## Current State

2026-10-23: all sub-tasks completed; epic rows done. Nothing committed: the change set awaits the
user's review (docs-manager 1.9.0, kickoff 0.8.0, PLUG-083 proposed).
