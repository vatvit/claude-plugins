---
title: "kickoff: ask who works on the tasks (task assignee mode) and write it to .task-config.json"
status: completed
type: feature
priority: medium
tags: ["kickoff-plugin", "task-plugin"]
depends-on: [PLUG-138]
created: 2026-11-16 13:04
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | |
| 20 | Requirements | done | R1–R5; question id R12 (never renumber) |
| 30 | Assessment | done | ready; prefix-mapping pattern exists |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | one mapping helper in lib.sh |
| 70 | Tests | done | spec in task |
| 80 | Subtasks | skipped | one small slice |
| 90 | Implementation | done | kickoff 0.12.0; all.sh green host + bash:5; 4 mutants red |
| 100 | Tech Debt | done | none; inspect prefix reader unified into task_registry_field |
| 110 | Reflection | done | kickoff CLAUDE.md Don't-regress line, README line |

## Description

Split from PLUG-138 at its Subtasks step: the kickoff half of R17. PLUG-138 adds the task plugin's
`assignees` config key (`off` | `unassigned` | `self`, absent = `off`). Kickoff should ask it when it sets
up the task plugin.

- A new questionnaire row after R8, asked when R6 = Markdown task files and task is installed:
  **"Who works on these tasks?"** ★ Just me (`off`) · A team, new tasks start unassigned (`unassigned`) ·
  A team, new tasks go to whoever creates them (`self`).
  The default may take a hint from A4/R5, but there is no team-size question today. Decide at requirements.
- `kickoff/scripts/scaffold.sh:81` writes `.task-config.json` as a literal printf. It writes the key
  only when the answer is not `off`, so a solo project's config stays as it is today.
- Plugin independence: kickoff writes the key as config data only, and never sources task code.
- The existing-project / close-the-gaps path: an existing `.task-config.json` without the key counts as
  `off`, so it is not a gap.

## Acceptance criteria

- The row is asked only when the task plugin is installed and R6 = task files. The default is `off`.
- The `off` answer leaves the generated `.task-config.json` byte-identical to today's.
- `unassigned`/`self` add `"assignees": "<mode>"`. Tested in `kickoff.test.sh` on both targets.
- Kickoff version bumped and synced per root `CLAUDE.md`.

## Context

**Depends on PLUG-138** (completed): task 1.7.0 reads `"assignees": "off" | "unassigned" | "self"` from
`.task-config.json` *or* from the project's entry in the task registry (`resolve-config.sh` prints every key).
Absent counts as `off`. `assign.sh <proj> mode …` writes it, but only to a project-local config.

**Kickoff code (read 2026-11-16):**
- `skills/kickoff/references/questionnaire.md` §R is the single source. Scripts parse its rows
  (`lib.awk`), so a new row is code. **IDs are keys in `.kickoff-answers`: never renumber R9–R11.** The
  new question is **R12**, placed after R8 in the table. Notes paragraph "R6–R11" → "R6–R12".
- `scripts/scaffold.sh`: reads `A1 R7 R8 R9` via `get.awk`. In the repo, it seeds `.task-config.json` with a
  printf and `once` (seeded, written once, never overwritten, 3c). Outside it, `registry-insert.awk` (env
  `KO_ROOT`/`KO_DIR`/`KO_PREFIX`) inserts the registry entry. It maps option text by prefix (`Outside*`,
  `One*|Minimal*`), which is the accepted pattern.
- `scripts/inspect.sh`: hints R6/R7/R8 from `.task-config.json` (`json_str`) or the registry entry. `infer.awk`
  maps a hint to the first option that starts with it.
- `scripts/gaps.sh`: `R6:"Markdown task files"*` → a gap when there is no task setup. Answers are matched by
  the start of the option text.
- Tests: `scripts/test/all.sh` (kickoff, scaffold, existing, home, defaults, ports). `autofill` accepts
  ★ defaults, so a new ★ "Just me" default leaves every existing fixture's config unchanged. Run on the
  host and in `bash:5`.
- Version 0.11.1.

**Parallel sessions:** the docs-manager session (PLUG-140/141) is not in kickoff. Shared files at release:
`.claude-plugin/marketplace.json` and the root README.

## Requirements

- **R1** A new question **R12 "Who works on these tasks?"**: `★ Just me · A team — new tasks start unassigned ·
  A team — new tasks go to whoever creates them`, asked when `R6 = Markdown task files and task installed`.
  Goes to `.task-config.json`.
- **R2** Scaffold, in the repo: "Just me" seeds today's `.task-config.json` byte for byte. A team answer adds
  `"assignees": "unassigned"` or `"self"`. Outside the repo: the same key in the inserted registry entry.
- **R3** An existing project: inspect.sh proposes R12 from the config or registry entry. A key of `unassigned`
  or `self` gives that team option, and a missing key gives "Just me".
- **R4** gaps.sh: R12 = a team answer while the config or registry entry has no `assignees` → a gap
  ("no assignees mode", fix: task's `assign.sh <proj> mode …`). The seeded config is never rewritten by scaffold (3c).
- **R5** Kickoff only writes config data. It never sources task code. 0.11.1 → 0.12.0, synced, with triggers
  unchanged (no new user phrase).

## Architecture

The option-to-mode mapping lives in one place, an `assignees_mode` function in `scripts/lib.sh` (team
start → `unassigned`, team other → `self`, else empty), used by scaffold (both paths) and gaps.
`registry-insert.awk` takes `KO_ASSIGNEES`, and adds the line only when it is non-empty. inspect.sh maps
the key back to a hint. Hints are prefixes, so the wording stays in the questionnaire.

## Test specification

- kickoff.test.sh: R12 is asked only with task installed and R6 = task files, and skipped otherwise.
- scaffold.test.sh: the default gives a byte-identical config. `A team — new tasks start…` → `"assignees": "unassigned"`,
  and whoever → `self`. The registry entry carries it (home.test.sh fixture, R7 = Outside).
- existing.test.sh: inspect proposes R12 from a config with the key and from one without it. gaps reports a team
  answer without the key, and nothing once it is added.
- Each new check is watched failing once (mutant).

## Implementation

kickoff 0.11.1 → 0.12.0 (plugin.json, marketplace.json; check-descriptions.sh ok).
- `questionnaire.md`: row **R12** after R8; the notes say R6–R12, plus an R12 bullet.
- `scripts/lib.sh`: `assignees_mode` (answer → `unassigned`/`self`/nothing, the one mapping) and
  `task_registry_field` (a registry entry's string field, one-line entries too). That replaced inspect.sh's
  inline prefix awk, which was greedy on a one-line entry.
- `scaffold.sh`: R12 read with get.awk. The in-repo printf adds `assignees` only for a team; `registry-insert.awk`
  takes `KO_ASSIGNEES`. `inspect.sh`: `hint_assignees` from the config or registry entry. `gaps.sh`: a team
  answer without the key is a gap, and its text names the task plugin's `assign.sh … mode <m>`.
- Tests: kickoff 4g2, 4q2, 1a count (61 → 62); scaffold 2e2 (default byte-identical), 2e3 ×2, 4d2/4d3 (registry);
  existing 2f2, 3b2, 3b3 (one-line entry), 3c–3f (gaps, inspect). All suites ALL GREEN on the host and `bash:5`.
  Mutants (printf line, gap, registry field, inspect hint) each red.

## Current State

All steps done, and the code works. Completed 2026-11-16 by `/task finish`. Nothing committed.

## Release (2026-11-16)

Version bump held back on the user's instruction: several features ship together later. `kickoff` stays at 0.11.1 in
`plugin.json` and `marketplace.json`. The version named under Implementation is the one this change will get
when it is released. Keywords and docs stay as written.
