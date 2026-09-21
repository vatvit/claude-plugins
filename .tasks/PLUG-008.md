---
title: Ship the task skill as a plugin, sourced from this repo
status: in-progress
type: feature
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | Scripts already meet shell conventions; port is packaging+prose. Consumers use BOTH config mechanisms. Old repo holds 3 skills. See ## Context |
| 20 | Requirements | done | R1–R10; R6 parity is the binding one, R3/R9 the ones that can fail |
| 30 | Assessment | done | Scripts already conform; work is packaging + prose + 2 new test cases |
| 40 | POC | skipped | Nothing unknown — layout is copied from task-roadmap, scripts run unchanged |
| 50 | Domain | done | 6 terms fixed so PLUG-009/010 do not drift; see ## Domain |
| 60 | Architecture | done | D1–D8; D4 session-storage optional, D5 config unchanged, D6 no lib.sh yet |
| 70 | Tests | done | 2 suites, 28 cases, dual-target; new port.test.sh covers R2/R3/R4/R5/R9 |
| 80 | Subtasks | skipped | One slice; the follow-ups already exist as PLUG-009/010 |
| 90 | Implementation | done | task/ plugin built; shebang portability bug found by the container run and fixed |
| 100 | Tech Debt | done | PLUG-011 raised (docs-manager shebangs); cutover flagged as unfinished |
| 110 | Reflection | done | repo CLAUDE.md: env-form shebang rule + why it hides |

## Description

The `task` skill (`/task create|list|show|do|finish|status|workflow`) currently lives in a
separate repo, `~/projects/vatvit/claude-skill-task`, and is installed by hand-made symlinks
into `~/.claude/skills/`. Move it into this marketplace as a fourth plugin, `task/`, with
**this repo as the new home of the source code**.

`claude-skill-task` is to be abandoned once every consuming project has switched to the
plugin. It is not a mirror and not a submodule — after the transition it is archived.

## Why

- It is the odd one out. `session-storage`, `docs-manager` and `task-roadmap` all install
  via `/plugin install …@vatvit-plugins`; only `task` needs `ln -s`, which breaks for anyone
  else and after any path change.
- `task-roadmap` already declares itself a complement to `/task` and reads `tasksDir` from
  `.task-config.json`. The two halves of the same workflow should version side by side.
- The skill hardcodes `{skillDir}` as an absolute `/Users/vatvit/projects/...` path in its
  own docs and in consuming projects' `settings.local.json` permission entries.
  `${CLAUDE_PLUGIN_ROOT}` removes that whole class of breakage.
- Versioning and rollback come for free instead of being "whatever main happens to be".

## Scope

- New `task/` plugin directory following **Adding a New Plugin** in CLAUDE.md:
  `.claude-plugin/plugin.json`, `skills/task/SKILL.md`, `scripts/`, `README.md`, `CLAUDE.md`,
  a `marketplace.json` entry, and a row in the Plugins table.
- Port the full current feature set — no behaviour change in this task: create / list / show /
  do / finish / status / workflow, epics and the epic index, the bare-ID and active-epic list
  views, the workflow table, `allocate-id.sh` ID locking, and the seven helper scripts.
- Replace every `{skillDir}` reference with `${CLAUDE_PLUGIN_ROOT}` and make the scripts
  resolve their siblings relative to it rather than to a fixed path.
- Port `references/` and `examples/`; port the existing `scripts/test/epic-dashboard.test.sh`
  and prove the **Plugin Independence** rule: copy `task/` somewhere with no siblings and no
  repo root, run the tests there.
- Verify the optional session-storage integration still degrades silently when that plugin is
  absent — the skill detects it by a context string today, which already satisfies the
  independence rule, but it must be confirmed, not assumed.
- Check the skill `description:` trigger phrases against the other three plugins'. Today's
  vocabularies are disjoint (docs-manager: docs/index/links/diagram; task-roadmap:
  roadmap/gantt/timeline); `task` owns *task / TASK-NNN / epic / workflow / subtask* and must
  not start competing with `task-roadmap` for *roadmap*.
- Migration: switch consuming projects off the symlink onto
  `/plugin install task@vatvit-plugins`, remove `~/.claude/skills/task`, and fix the absolute
  script paths sitting in each project's `.claude/settings.local.json` allow-list.
- Archive `claude-skill-task` once the last project has moved — README pointing here.

## Out of scope

- **Token/structure optimisation of SKILL.md.** See *Follow-up* — deliberately a separate
  task so this one stays a pure move with a diffable before/after.
- Any change to task-file format, workflow steps, or command behaviour.
- Merging `task` and `task-roadmap` into one plugin. They stay independent per the
  Plugin Independence rule.

## Acceptance criteria

- `/plugin install task@vatvit-plugins` gives a working `/task` in a project with no symlink
  and no `~/.claude/skills/task`.
- Every command works against an existing task set — verified on this repo's own `.tasks/`
  (`PLUG-*`), which is the most demanding case available: epics, an epic index, and a
  project-local `.task-config.json`.
- `task/scripts/test/*.test.sh` passes both in the repo and in a copy of `task/` isolated
  from its siblings.
- No absolute `/Users/...` path remains anywhere in the plugin.
- `plugin.json`, `marketplace.json`, the Plugins table and the skill `description:` all agree
  (the three-way drift listed under *Changing an Existing Plugin*).
- The string `claude-skill-task` appears nowhere in the shipped plugin except a provenance
  line in its README.

## Context

No epic. PLUG-001..007 are all the `diagram-support` epic (docs-manager); this is the first
task in a new area, so the inherited material is *conventions*, not prior art on this feature.

**Chain:** PLUG-008 → **PLUG-009** (extract rendering into scripts) → **PLUG-010** (router
split). All three edit the same `SKILL.md`; the order is not negotiable and they cannot run in
parallel sessions.

**Collisions:** none. PLUG-008 is the only `in-progress` task in this repo.

### Readiness — better than expected

The seven scripts already satisfy every rule in *Shell Conventions*: no `sed -i`, no
`declare -A`, no `globstar`/`${var^^}`, and **no absolute paths anywhere in the shell code**
(checked by grep, 2026-09-22). They are pure bash + awk with no runtime, which is the repo
standard already.

So the port is **packaging and prose, not a script rewrite**. The absolute-path problem lives
entirely in (a) `SKILL.md`'s Scripts section, which names
`/Users/vatvit/projects/vatvit/claude-skill-task/skills/task/scripts/` outright, and
(b) consuming projects' permission allow-lists.

### Conventions to follow (from the siblings, not to be re-derived)

- **Path placeholder:** prose in a SKILL.md writes `<PLUGIN_ROOT>/scripts/x.sh`
  (task-roadmap's SKILL.md:26); `hooks.json` writes `${CLAUDE_PLUGIN_ROOT}`. That pair replaces
  every `{skillDir}` occurrence.
- **Layout to mirror:** `task-roadmap/` is the closest analogue —
  `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, `scripts/{lib.sh,*.sh,test/*.test.sh}`,
  `CLAUDE.md`, `README.md`, optional `hooks/hooks.json`.
- **`tasks` / `.tasks` are reserved directory names** at repo root and must never appear in
  `marketplace.json`.
- **Plugin Independence (PLUG-006):** never source a sibling plugin's file; DRY applies *within*
  a plugin; reading a key out of a file another tool owns is fine provided it degrades. The proof
  is the standalone-copy test.
- **Dual-target tests (PLUG-002/004):** run the suite on the host *and* in a `bash:5` container.
  This is the only thing that catches BSD/GNU and busybox divergence, and it has paid off twice.
  Never assert on `diff` output *shape*.
- **`set -e` + `v="$(helper)"` aborts when the helper legitimately finds nothing** (PLUG-005,
  shipped as a live bug in task-roadmap 1.0.1). Any helper whose empty result is normal ends in
  `|| true` / `return 0`.
- **Test the path where nothing happens** (PLUG-005, case 18a): the opt-out path is what most
  users experience and the least likely to be exercised by hand. Here that is
  **session-storage absent** — the single most important test in the port.
- **Write the no-regression cases before refactoring** (PLUG-002). Applies to PLUG-009/010 more
  than here, but the port is the moment to write them.

### Source repo

`~/projects/vatvit/claude-skill-task`, branch `main`, commit `4c5ca2d`.
`skills/task/{SKILL.md,scripts/,references/,examples/}`.
`SKILL.md` 1039 lines / 52 KB (~13k tokens, resident on every invocation).
Scripts (~820 lines): `resolve-config.sh`, `allocate-id.sh`, `resolve-task.sh`, `read-tasks.sh`,
`update-epic-index.sh`, `resolve-epic.sh`, `epic-dashboard.sh`, plus
`scripts/test/epic-dashboard.test.sh` (11 cases).

**Size, against the siblings:** docs-manager 167 lines, task-roadmap 66, session-storage 50.
At 1039 the task skill is 6× the largest sibling — PLUG-010 is conformance to the repo norm,
not polish.

**The old repo holds three skills, not one:** `task`, `skill-creator` **and**
`refactoring-analyse` — the last two are also symlinked into `~/.claude/skills/`. Both need a
decision (port / retire / separate repo) before `claude-skill-task` can be archived. Neither is
in this task's scope.

### Consumers — two config mechanisms, not one

Project-local `.task-config.json`: `project-f` (PF), `project-e` (PE),
`project-b` (PB), `project-c` (PC), `project-a` (PA), `claude-plugins` (PLUG).

Global `~/.claude/project-tasks/config.json` additionally registers: `project-g` (PG, tasksDir
outside the repo at `~/.project-g/tasks`), `project-h`, `project-d`, and
`project-a/src/sub-a`. **The migration must cover both** — an earlier note in
this task said "projects holding a `.task-config.json`", which undercounts.

**Hardcoded paths to clean up** — `claude-skill-task` appears in five `settings.local.json`
allow-lists: `project-a` (11 entries), `claude-skill-task` (9), `project-d` (2),
`project-b` (1), `project-c` (1), plus two copies inside `project-b/.claude/worktrees/`.

**Install today:** `~/.claude/skills/{task,skill-creator,refactoring-analyse}` are symlinks into
the old repo. Removing the `task` symlink is part of the cutover; the other two are not.
## Requirements

- **R1** When the user runs `/plugin install task@vatvit-plugins` in a project that has no
  `~/.claude/skills/task` symlink, the `/task` skill shall be available with all seven
  commands (`create`, `list`, `show`, `do`, `finish`, `status`, `workflow`).
- **R2** The shipped plugin shall contain no absolute filesystem path. Script locations are
  expressed as `<PLUGIN_ROOT>/scripts/…` in prose and `${CLAUDE_PLUGIN_ROOT}` in any hook.
- **R3** Where the `session-storage` plugin is not installed, every command shall complete
  with active-task tracking silently disabled — no error, no prompt, no degraded output.
- **R4** The plugin shall not source, read or assume any file belonging to a sibling plugin.
- **R5** Scripts shall run under bash 3.2 and under both BSD/GNU and busybox userland.
- **R6** For any command and any task set, output shall be unchanged from the pre-move skill
  at source commit `4c5ca2d`. This slice changes packaging, never behaviour.
- **R7** ID allocation shall keep its invariants: allocation only via `allocate-id.sh`, under
  the lock, self-healing from `max(nextId, highest existing)`, never clobbering.
- **R8** `plugin.json`, `marketplace.json`, the repo Plugins table and the SKILL.md
  `description:` shall agree on name, version and capability.
- **R9** The test suite shall pass from a copy of `task/` placed outside this repo with no
  sibling plugins present.
- **R10** The skill's trigger phrases shall not overlap with `docs-manager`
  (docs/index/links/diagram/CLAUDE.md), `task-roadmap` (roadmap/gantt/timeline) or
  `session-storage` (storage/session data).

## Assessment

Ready. The gap between the source skill and this repo's standards is narrower than the task
assumed — see `## Context`. Work remaining is:

1. **Mechanical** — copy `skills/task/{SKILL.md,references,examples}` and `scripts/` into
   `task/`, add `.claude-plugin/plugin.json`, `README.md`, `CLAUDE.md`, marketplace entry,
   Plugins-table row.
2. **Prose** — replace `{skillDir}` (12 occurrences) and the hardcoded Scripts-section path
   with the `<PLUGIN_ROOT>` convention; drop the "Installation via symlink" framing.
3. **Verification** — R3 and R9 are the two that can actually fail, and neither is covered by
   the inherited `epic-dashboard.test.sh`. They need new cases.

No code change is required to satisfy R5 or R2-in-scripts: both already hold.

## Domain

Terms used consistently across the plugin (they already exist in the skill; fixing them here
so PLUG-009/010 do not drift):

- **task** — one `PREFIX-NNN.md` file. **sub-task** — a task with an `epic:` field.
- **epic** — a task with `type: epic` and an `epic-name`; the parent document, not a label.
- **workflow step** — a row in a task's `## Workflow` table; the table *is* the state.
- **tasksDir / prefix** — resolved per project by `resolve-config.sh`, from project-local
  `.task-config.json` or the global `~/.claude/project-tasks/config.json`.
- **active task** — a task id held in session-storage's `active-tasks` for *this session*;
  distinct from `status: in-progress`, which is durable and lives in the file.
- **plugin root** — the installed `task/` directory; `${CLAUDE_PLUGIN_ROOT}` at runtime.

## Architecture

- **D1 — One plugin, `task/`, mirroring `task-roadmap/`.** Same layout, same manifest shape,
  same `scripts/test/` convention. Nothing novel; the value here is being unremarkable.
- **D2 — Version starts at `1.0.0`.** The source repo has no version history worth carrying,
  and a fresh `1.0.0` makes the marketplace entry honest about what is being installed.
- **D3 — `<PLUGIN_ROOT>` in prose, `${CLAUDE_PLUGIN_ROOT}` in hooks.** Copies task-roadmap
  exactly. No hook is shipped in this slice, so only the prose form appears.
- **D4 — Session-storage stays a *detected* optional integration, not a declared dependency.**
  The skill finds it by the `SESSION STORAGE PLUGIN:` context string and skips silently when
  absent. This already satisfies Plugin Independence — no sibling file is ever sourced — and
  keeps `task` installable alone. R3 gets an explicit test rather than an assumption.
- **D5 — Config stays where it is.** `.task-config.json` and the global config are read
  unchanged; no `.task.json` is introduced. `task-roadmap` already reads `tasksDir` out of
  `.task-config.json`, so the file is a shared *data* contract between two plugins, which the
  independence rule expressly permits. Changing its location would break task-roadmap.
- **D6 — No `lib.sh` extraction in this slice.** The seven scripts each stand alone today.
  Introducing shared helpers is a behaviour-risk refactor and belongs with PLUG-009, which
  will have the no-regression cases in place first.
- **D7 — The old repo is left untouched by this task.** It is archived in a follow-up once
  the three skills it holds have each been decided. Deleting it here would strand
  `skill-creator` and `refactoring-analyse`.
- **D8 — Tests are dual-target** (host + `bash:5` container) per the inherited convention,
  and the standalone-copy run is part of the suite's contract, not a manual step.

## Tests

Two suites, both dual-target (host + `bash:5` container), both runnable from a copy of
`task/` outside this repo.

- **`scripts/test/epic-dashboard.test.sh`** — inherited, 11 cases, unchanged. Pins epic
  membership parsing (list items and table rows are members; prose is commentary).
- **`scripts/test/port.test.sh`** — new, 17 cases, written for this slice:
  - *Packaging* (T1–T6): no absolute path; the old repo named only in the README provenance
    line; no sibling-plugin path; bash-3.2 constructs only; no `sed -i`; every script
    executable; `env`-form shebang.
  - *Standalone copy* (T7–T13): the plugin is copied to a temp dir with no marketplace repo
    above it and no siblings beside it, then driven end to end — config resolution, two ID
    allocations (no collision), frontmatter read-back, `read-tasks` JSON, epic index build,
    epic resolution by name, dashboard sub-task detection.
  - *Session-storage absent* (T14–T15): no script references `storage.sh`, and the entire
    end-to-end run above happened with session-storage nowhere present.

`port.test.sh` had to exclude itself from its own greps — a test that searches for
`#!/bin/bash` and `sed -i` necessarily contains both strings, and without the exclusion every
packaging check reported the test file as the violation.

**Parity (R6)** was checked by diffing each script's output between the source repo at
`4c5ca2d` and the ported copy, on two real task sets: this repo's `.tasks/` (PLUG, includes an
epic) and `project-a/tasks` (PA, 1347 tasks). `read-tasks`, `resolve-task`,
`resolve-epic`, `resolve-config` and `epic-dashboard` were byte-identical on both.

## Implementation

`task/` created per D1:

```
task/.claude-plugin/plugin.json      name task, version 1.0.0
task/skills/task/SKILL.md            + version: 1.0.0 in frontmatter
task/skills/task/{references,examples}/
task/scripts/*.sh + scripts/test/{epic-dashboard,port}.test.sh
task/README.md                       install, commands, config, provenance
task/CLAUDE.md                       layout + don't-regress list
```

Repo-level: `marketplace.json` gained the `task` entry (first in the array), `CLAUDE.md` gained
the Plugins-table row and the structure-tree line.

Path rewrite: the 5 `{skillDir}/scripts/` references became `<PLUGIN_ROOT>/scripts/`; the
duplicated `## Scripts` heading and its hardcoded
`/Users/vatvit/projects/vatvit/claude-skill-task/...` paragraph were replaced with the
plugin-root convention; the test-runner path inside `epic-dashboard.test.sh` was corrected.

**One real bug fixed, not just moved.** Every script carried `#!/bin/bash`. That works on
macOS and dies on Alpine, where bash is at `/usr/local/bin/bash` — and it fires only when a
script *execs* another rather than being run as `bash script.sh`, which `allocate-id.sh` does
to `resolve-config.sh`. Eight cases failed in the container on the first dual-target run while
all passed on the host. All shebangs are now `#!/usr/bin/env bash`, and T5b fails if the
hardcoded form returns. The repo `CLAUDE.md` Shell Conventions section gained the rule;
`docs-manager` has the same latent defect and is ticketed as **PLUG-011**.

Not done, deliberately: no `lib.sh` extraction (D6), the old repo untouched (D7), and no hook
shipped — `/task` is invoked, not triggered.

## Tech Debt

- **PLUG-011** — `docs-manager` scripts still use `#!/bin/bash`. Latent: its suite invokes
  them as `bash script.sh`, so the shebang never fires today.
- **PLUG-009 / PLUG-010** stand unchanged — the move did not reduce `SKILL.md`, and at ~1040
  lines against siblings of 167 / 66 / 50 it is now visibly the outlier in this repo.
- **Cutover is not done.** The plugin exists and passes; consuming projects still load the
  skill through `~/.claude/skills/task`. Removing that symlink, installing the plugin in the
  ten registered projects and clearing 24 stale allow-list entries is the remaining half of
  this task's *Scope* and has not been started — see `## Current State`.

## Reflection

**Repo `CLAUDE.md`** gained the `env`-form shebang rule under Shell Conventions, with the
reason it hides (only `exec` triggers it) rather than just the instruction.

**Lessons worth keeping:**

- **The dual-target convention paid for itself on its first use in a new plugin.** Eight
  green tests on macOS, eight red on Alpine, from a one-character class of defect that no
  amount of reading would have surfaced. It cost one `docker run`.
- **A port is the cheapest moment to find latent portability bugs, because it is the first
  time the code is run somewhere new.** The shebang had been wrong for the entire life of the
  source repo and never mattered while the only caller was a symlinked skill on one Mac.
- **A test that greps for forbidden patterns will match itself.** Obvious in hindsight,
  invisible while writing, and it presents as five real-looking failures. Exclude the test
  file by path in the scan helper, once, rather than per check.
- **"Port it unchanged" was the right scope and still admitted one fix.** The shebang change
  is not behaviour drift — it is the difference between the plugin working and not working on
  a supported target, which is exactly what R5 asked for.

## Current State

**Build status:** plugin complete and green — 28 tests (11 + 17) passing on host *and* in
`bash:5`. Output parity with source commit `4c5ca2d` verified byte-for-byte on the PLUG and
PA task sets. Nothing committed in either repo.

**Known issues:** none in the plugin itself.

**Next actions (the cutover, not yet begun):**
1. Commit `task/`, the marketplace entry and the CLAUDE.md changes in `claude-plugins`.
2. `/plugin install task@vatvit-plugins`; remove the `~/.claude/skills/task` symlink.
3. Migrate the ten registered projects — six with `.task-config.json` (PF, PE, PB, PC,
   PA, PLUG) and four registered only in the global config (project-g, project-h, project-d,
   project-a/src/sub-a).
4. Clear 24 `claude-skill-task` allow-list entries across five `settings.local.json` files,
   plus two inside `project-b/.claude/worktrees/`.
5. Decide `skill-creator` and `refactoring-analyse` before archiving the old repo.

## Follow-up (raised, not this task)

`SKILL.md` is ~13k resident tokens because it inlines instructions that are really programs:
`### LIST` alone is 223 lines of hand-executed filtering, grouping, sorting, collapsing and
column rendering, and `### DO` is another 146. Both follow-ups are behaviour-preserving and
must land **after** this move, in this order — all three edit the same file:

- **PLUG-009** — extract the data work into `list-tasks.sh`, `set-status.sh`,
  `session-active.sh`. Removes ~300 lines and makes the rendered output reproducible.
- **PLUG-010** — split the remainder into a router plus on-demand `commands/` and
  `references/`. Estimated ~13k → ~2k resident tokens.

Neither should be mixed into this move: keeping it a pure port is what makes the before/after
diffable.
