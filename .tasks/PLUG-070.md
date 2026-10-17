---
title: adopt a legacy project — docs and kickoff as if they had been there from the start
status: proposed
type: epic
epic-name: legacy-onboarding
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
  kickoff); *adopt* stays crew's. Refine the repo CLAUDE.md line "never says *init*" accordingly at
  Reflection.
- ~~**Who owns `docs/` layout.**~~ Decided 2026-10-17 (user agreed): docs-manager owns content and layout
  of `docs/`; kickoff writes only the charter and answers, and skips its K1 docs skeleton when `docs/`
  already exists. PLUG-052 (which changes that skeleton) must respect this. The epic split into
  PLUG-071/072 is also agreed.

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

## Current State

Proposed 2026-10-17. Not started. PLUG-071 and PLUG-072 touch disjoint plugins and can run in parallel
sessions; PLUG-072 only *reads* `docs/` if present, so it does not wait on PLUG-071. Naming (`init`
argument) and docs-layout ownership are decided (see above). Note: PLUG-049 (kickoff-next) also edits kickoff — release
both kickoff epics in one bump if they land close together.
