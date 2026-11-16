---
title: "task: opt-in assignee field — who a task is for, chosen at init, list shows mine + unassigned"
status: completed
type: feature
priority: medium
tags: ["task-plugin"]
created: 2026-11-13 13:04
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | `## Context`: filters, grouping and `~` already work for `assignee`; the gaps are listed |
| 20 | Requirements | done | `## Requirements` R1–R17; Q2 filter+drill-down and Q4 `/task assign` decided by the user |
| 30 | Assessment | done | ready; registry-entry mode edit refused (rare) |
| 40 | POC | skipped | no risky unknown |
| 50 | Domain | skipped | no domain model; person vs session = Q5 |
| 60 | Architecture | done | `## Architecture`: resolve-config me=, list flags, assign.sh, 2 lib helpers |
| 70 | Tests | done | `## Test specification` T1–T13, new `assignee.test.sh` |
| 80 | Subtasks | done | kickoff half (R17) split to PLUG-142; the rest stays one slice, task plugin only |
| 90 | Implementation | done | task 1.7.0; assignee.test.sh 93 green host + container; mutants red |
| 100 | Tech Debt | done | no debt tickets; see `## Implementation` |
| 110 | Reflection | done | docs updated in the same change; vocabulary split noted in root CLAUDE.md |

## Context

**Epic:** none. No earlier task mentions a task assignee. crew's task ownership is a *session*, not a
person: crew PLUG-060 (one task, one session) and PLUG-061 (`crew task <ID>`, `--for <name>`,
`scripts/task.sh task_assign`). It is stored by crew, never in the task file. Keep the two apart (Q5).

**Already works today, no code needed (probed on a temp task set, 2026-11-16):**
- `list-tasks.sh … assignee=bob@x.io` gives an exact match, and `assignee=_` gives unassigned. The filter is
  generic over any frontmatter field (`#F` records → `matches()` in `list-render.awk`).
- `assignee~BOB` gives a case-insensitive substring match. `group=assignee` groups the tasks, with a `(no assignee)` group.
- `read-tasks.sh` passes any frontmatter key through. Only `tags` gets special decoding.
- So the real gaps are: (1) an **Assignee column**; (2) the **`me` shorthand**, since `none` can just be
  documented as `_`, which is the existing unset syntax and settles part of Q3; (3) the **default view / sort
  order** (Q2); (4) the **mode** in config; (5) assigning on `/task create` and `/task do`; (6) the
  **override file**; (7) the kickoff question.

**Code to touch (task plugin):**
- `task/scripts/list-render.awk` `print_out()`: columns appear only when some task fills them (`anyc`/`anyt`
  pattern, Created column from PLUG-099, `created.test.sh`). An Assignee column follows that pattern, but
  it must also be gated on mode ≠ `off`. Otherwise an `assignee:` written by hand would change the output
  in `off` mode, and that breaks AC 1 ("byte-identical").
- `task/scripts/list-tasks.sh`: argument parsing and `#C` config records. The mode and "me" get passed here
  as `#C` lines, and `assignee=me` is rewritten to the id before the `#F` line.
- `task/scripts/lib.sh`: `task_config_read` / `task_config_edit` (the one JSON reader/writer) read and
  set the `assignees` key. `task_project_dir` maps a worktree to the main tree.
- Override location: follow `idgit_cache_file` in `id-git.sh`, which keeps per-clone state in
  `$(git rev-parse --git-common-dir)/task-ids/`, shared by worktrees and never committed. A sibling dir,
  e.g. `<common-dir>/task/`, plus `<project>/.task/` outside git (root `CLAUDE.md` *Config convention*,
  per-project state). Decide the exact name at architecture.
- Skill prose: `commands/create.md` (set the field per mode), `commands/do.md` Start (assign on do; ask
  before taking over), `references/configuration.md` (the "First run" paragraph asks `tasksDir` + `prefix`,
  add the mode; document the key), `references/task-format.md` reserved-fields table, `SKILL.md` description.
- Tests: `task/scripts/test/*.test.sh` sourcing `test/lib.sh`. `list-tasks.test.sh` (41) and
  `created.test.sh` are the models for a column test, and `config.test.sh` has the no-HOME cases. Run with
  `bash task/scripts/test/run.sh`, both on the host and in the `task-test` image (`scripts/test/Dockerfile`, busybox awk).

**Kickoff slice (separate, disjoint files):** `kickoff/skills/kickoff/references/questionnaire.md` R6–R11
table (R7 = tasks dir, R8 = prefix; a new R-row for the mode, asked when R6 = task files and task is
installed). `kickoff/scripts/scaffold.sh:81` writes `.task-config.json` as a literal printf, so it would gain
the `assignees` key. A natural default: `off` when A4 = Mine and solo, but the questionnaire has no
team-size question today (A4 is ownership, R5 is parallel Claude sessions). Decide at requirements.

**Trigger-phrase collision (found now):** crew's description owns "assign tasks to sessions" and
"crew task". The planned task phrase "assign a task" is close to it. Prefer "assignee", "my tasks",
"unassigned tasks" and "assign a task to a person", and check them against crew at implementation.

**Parallel-session collisions:** PLUG-140 and PLUG-141 are in progress and both are docs-manager only. PLUG-139
(blocked) touches `task/skills/task/SKILL.md` among others, for skill size. That overlaps this task's
SKILL.md and command-file edits, so coordinate before editing those files if 139 gets unblocked.

## Description

Add an optional `assignee` field to task files, and teach `/task list` about it. **Off by
default**: a solo-dev project (most projects) keeps today's behaviour exactly, no field, no column.

- **The value** is a free string: an email or any custom id (`assignee: alice@example.com`,
  `assignee: alice`). Absent or empty means *unassigned*.
- **Assignee mode** — a project choice, so it goes in `.task-config.json` (committed: it is the
  team's decision, not personal data). Working name `assignees`:
  - `off` (default, also when the key is absent): solo dev, nothing changes;
  - `unassigned`: new tasks are created unassigned;
  - `self`: new tasks are assigned to the creating user.
  **Asked at initialisation**: when `/task` creates `.task-config.json` (today it asks for
  `tasksDir` and `prefix`), and in **kickoff** when the task plugin is installed. Kickoff's part is
  a separate slice (kickoff plugin, disjoint files; split at the Subtasks step). Plugin independence:
  kickoff writes the key only as config data, never sources task code.
- **The user's own id** (who "my tasks" means) is **never committed**: it is personal, and a
  teammate on the same repo has a different one.
  - **Default: the Claude account email.** Decided by the user: not git, because a project may
    have no git, while Claude is always present. Claude Code puts the signed-in account's email
    into Claude's context; scripts cannot read it. So the **skill** (Claude) reads it from its
    context and passes it to the scripts as a quoted value (env var or argument). The scripts
    never try to discover it themselves.
  - **No account email in context** (it happens: API-key auth, Bedrock/Vertex, other hosts with no
    claude.ai sign-in): Claude **asks the user how to identify them** and saves the answer as the
    per-project override. Decided by the user.
  - **Overridable per project** with a custom id, stored outside version control and outside HOME
    (cloud sessions have no persistent `~/.claude`; root `CLAUDE.md` *Without HOME*).
  - **Unknown id: asked lazily, only when needed** (decided by the user). The id is needed only when
    the project's mode is not `off` **and** the user either filters by "me" (`assignee=me`) or starts
    a task (`/task do`, which assigns it to them). Nothing else asks. Then Claude asks, and
    remembers: for the session (session-storage when present, else the conversation), and in the
    per-project override when that location is writable and persists. A new session that has lost
    it (e.g. a cloud sandbox) simply asks again. No committed alias map, no HOME file.
    Consequence: a plain `/task list` with an unknown id does not ask; it shows unassigned on top.
- **`/task list`** (only when the mode is not `off`):
  - filters by assignee (`assignee=<id>`, plus a shorthand for me and for unassigned);
  - shows an Assignee column;
  - by default shows **my and unassigned** tasks, or at least puts them **on top** (see Q2).

## Open questions (decide at requirements/architecture)

1. **Where the per-project override lives.** `$(git rev-parse --git-common-dir)/task/` in a git
   repo (shared by every worktree, never committed), `<project>/.task/` outside git. Cloud is
   settled by the lazy-ask rule above: what is lost is asked again (Cowork and Claude Code on the
   web keep nothing between sessions outside the project; see PLUG-111). Rejected: a committed
   alias map (puts an email in git), a per-account HOME file (lost in cloud, and the account email
   already is per-account), git `user.email` (projects without git).
   **Decided (user): `/task do` in any mode other than `off`** assigns an unassigned task to the
   user automatically; a task already assigned to someone else → ask before taking it over; already
   the user's → nothing. `unassigned` vs `self` differ only at `/task create`.
2. **Default view: filter or sort?** Hiding other people's tasks by default can surprise. Option:
   sort mine → unassigned → others, with an `assignee=me` filter for the strict view. Or filter by
   default with `assignee=all` to widen.
3. **Shorthands**: `assignee=me`, `assignee=none` (unassigned), `assignee=all`? Must not collide
   with a real id literally named `me`/`none`.
4. **Changing it later**: a `/task assign <id> [who]` command, or only by editing the field?
   Never changed by Claude without the user asking, like `status`. And how to switch the mode on
   for an existing project (re-run the init question?).
5. **Relation to crew**: crew assigns tasks to *sessions*; this is a *person*. Keep them separate
   fields, and say so in both plugins' docs so the words don't compete (trigger-phrase check).
6. **Matching**: case-insensitive for emails? Compare as strings in awk (`($1 "") == id`, root
   `CLAUDE.md` awk traps).

## Acceptance criteria (draft)

- Mode `off` or no `assignees` key: output of every command is byte-identical to today's.
- Mode `unassigned` / `self`: `/task create` leaves the field empty / sets it to the user's id.
- `/task list assignee=<id>` shows only that id's tasks; the unassigned shorthand shows tasks with no assignee.
- `/task list` with no args shows my + unassigned tasks (or puts them first), per Q2, and an Assignee column.
- The user's id is the per-project override when set, otherwise the Claude account email passed in
  by the skill; with neither, Claude asks only on `assignee=me` or `/task do` (mode not `off`),
  remembers it for the session and, where it persists, the project; a plain list never asks. Works in a project with no git.
  The override file is outside git tracking (proved by a test: `git status` stays clean after setting it).
- Config creation asks for the mode; kickoff asks for it when the task plugin is installed (own slice).
- Works with HOME missing / read-only (container test cases).
- `references/task-format.md` lists `assignee` as a reserved field; SKILL.md trigger phrases get
  "assign a task", "assignee", "my tasks", "unassigned tasks"; plugin version bumped and synced
  per root `CLAUDE.md` *Changing an Existing Plugin*.

## Requirements

Supersedes the draft acceptance criteria above where they differ. EARS form; **R** = requirement.

### Decisions (2026-11-16)

| Q | Decision | By |
|---|----------|----|
| Q1 | Override at `<git-common-dir>/task/me`; outside git `<projectDir>/.task/me` | Claude (Context finding: matches `idgit_cache_file`) |
| Q2 | **Filter + drill-down**: mine + unassigned, then `+ N assigned to others — /task list assignee=all` | user |
| Q3 | Values `me`, `all` and `_` (the existing unset syntax). None of the three can be stored as an id | Claude |
| Q4 | **`/task assign <id> [who\|me\|_]`** backed by `assign.sh`, which `/task do` also uses. Mode switched with `assign.sh mode …` only when the user asks | user |
| Q5 | Separate from crew's session ownership; trigger phrases avoid "assign tasks to sessions" | Claude |
| Q6 | Ids are compared case-insensitively everywhere the plugin interprets them (`me`, default view, assign); `assign.sh` stores them lowercased | Claude |
| — | In mode `self`, `/task create` with an unknown id also asks. It is the third place that needs the id | Claude (follows from the user's lazy-ask rule) |
| — | Kickoff: a new R-row "Who works on these tasks?" with ★ Just me (`off`) · A team, new tasks unassigned · A team, new tasks go to their creator. Own sub-task | Claude |

### Config and identity

- **R1** The project config (`.task-config.json`, or the project's entry in the global registry) may hold
  `"assignees": "off" | "unassigned" | "self"`. When the key is absent, the mode is `off`. With any other value,
  scripts treat the mode as `off` and print one `WARNING` on stderr.
- **R2** While the mode is `off`, every script's stdout is byte-identical to the current release, even when a
  task file has an `assignee:` written by hand. The generic `assignee=`/`assignee~` filters keep working as
  they do today.
- **R3** The user's id ("me") is resolved in this order: the override file, then `TASK_ME`, which the skill sets
  to the Claude account email from its context, then *unknown*. Scripts never discover an id on their own
  (no git config, no HOME lookup).
- **R4** The override is `<git-common-dir>/task/me` inside git (shared by worktrees, never tracked) and
  `<projectDir>/.task/me` outside git. When that location cannot be written, the id stays session-only and
  the script says so once. Nothing goes to HOME.
- **R5** When the id is needed and unknown, Claude asks the user, then saves the answer (`assign.sh me <id>`)
  and stores it in session-storage when present. The id is needed for `assignee=me`, for `/task do` and for
  `/task assign` without `who` when the mode is not `off`, and for `/task create` in mode `self`. A
  script that needs an unknown id exits 3 with `ERROR: … needs your id`. Nothing else asks.

### List

- **R6** While the mode is not `off`, `/task list` shows an **Assignee** column after Created (or ID) and
  before Status, whenever any listed task has one. `digest` prints `assignee:` per task.
- **R7** While the mode is not `off` and no `assignee` filter is given, the open-task list shows only tasks
  that are mine or unassigned, then one line `+ N assigned to others — /task list assignee=all`. The line
  is omitted when N = 0. Other filters still apply on top. When the id is unknown, nothing is hidden and
  unassigned tasks sort first.
- **R8** Epic views (`/task list <epic>`, including the no-argument form for active epics) are never
  narrowed by assignee. They show the column.
- **R9** `assignee=me` matches my tasks, `assignee=_` unassigned ones, and `assignee=all` turns the default
  off. These combine with commas (`assignee=me,_`). Any other value is matched as an id.

### Create, do, assign

- **R10** In mode `unassigned`, `/task create` writes no `assignee` field. In mode `self` it writes `assignee: <me>`.
- **R11** In any mode other than `off`, `/task do` on an unassigned task assigns it to me. On my own task it
  does nothing. On someone else's, Claude asks before taking it over.
- **R12** `assign.sh <tasksDir> <prefix> <id> [<who>|me|_]` sets or clears the field through `task_fm_set`.
  It refuses `all`, an empty value, and a value containing a comma, a quote or a newline. It refuses with a
  hint when the mode is `off`. Claude never reassigns without the user asking.
- **R13** `assign.sh mode off|unassigned|self` writes the `assignees` key with `task_config_edit`. On first
  config creation, the skill asks for the mode along with `tasksDir` and `prefix` (default `off`).

### Cross-cutting

- **R14** Everything works without HOME and without git (container cases: HOME missing, HOME read-only,
  a project with no git).
- **R15** After `assign.sh me …`, `git status --porcelain` is unchanged (test).
- **R16** Docs and release: `task-format.md` lists `assignee` as a reserved field, `configuration.md` documents
  `assignees` and the override, `scripts.md` covers `assign.sh`, a new `commands/assign.md` is added, and the
  SKILL.md router and description get the new triggers ("assignee", "my tasks", "unassigned tasks",
  "assign a task to a person", "who is this task for"). Version bumped and synced per root `CLAUDE.md`.
- **R17 (kickoff slice)** When the task plugin is installed and R6 = task files, kickoff asks the mode and
  `scaffold.sh` writes `assignees` into the `.task-config.json` it creates.

Out of scope: the assignee in `epic-dashboard.sh` and task-roadmap, notifications, and any alias map.

## Assessment

The codebase is ready. Nothing needs refactoring first.
- **Mode reaches every command for free.** `resolve-config.sh` already prints every config key, so `assignees=`
  shows up with no change. It also has `PROJECT_DIR`, which makes it the natural place to resolve `me=`
  (override, then `TASK_ME`), and only when the mode is not `off`, so R2 holds.
- **`list-tasks.sh` takes `<tasksDir> <prefix>`, not a project dir**, and it cannot find the override itself.
  The skill passes `--assignees=<mode> --me=<id>` from resolve-config's output. Without the flags the list
  is today's list (R2 for free).
- **`list-render.awk`** has the hooks this needs. `passes(id, skip)` supports a field the caller filters
  itself. The `... and N more (use …)` text lines (`out_text`) are the drill-down pattern. The optional
  columns follow the `anyc`/`anyt` pattern in `print_out()`. `sortkey()` is where "unassigned first" goes.
- **Writers exist:** `task_fm_set` (frontmatter; an empty value removes the line) and `task_config_edit`
  (project-local JSON). Limit: `task_config_edit` cannot edit a project's entry in the *global
  registry*. `assign.sh mode` refuses there and says to edit the entry by hand. That is rare, and it's acceptable.
- **POC: skipped.** There is no risky unknown, only known patterns.
- **Domain: skipped.** It's a bash plugin with no domain model, and the one domain split (person vs crew's session) is Q5.

## Architecture

```
skill ──resolve-config.sh <proj>──▶ assignees=<mode>  me=<id|empty>   (me= only when mode ≠ off)
  │                                       ▲ override <common-dir>/task/me | <proj>/.task/me, else $TASK_ME
  ├─ list-tasks.sh <tasksDir> <prefix> --assignees=<mode> --me=<id> [assignee=me|_|all|<id>] …
  │        └─ #C assignees / #C me → list-render.awk: column, default filter + drill-down, me/all values
  └─ assign.sh <proj> <id> [who|me|_]     → task_fm_set assignee   (refuses in mode off)
     assign.sh <proj> me <id>              → writes the override (tmp+mv, diff-guarded); prints where, or
                                             `scope=session — <dir> not writable`
     assign.sh <proj> mode off|unassigned|self → task_config_edit (project-local config only)
```

- **One id normaliser** in `lib.sh`: `task_assignee_norm <v>` trims and lowercases, and rejects `,` `"` and
  newlines, plus the reserved `me`/`all`/`_`/empty when they are to be stored. Used by `assign.sh` and resolve-config's `me=`.
- **One override path** helper in `lib.sh`: `task_me_file <projectDir>`. It follows the
  `idgit_cache_file` pattern: the git common dir gives `<cd>/task/me`, and no git gives `<projectDir>/.task/me`.
  Used by resolve-config (read) and assign.sh (write).
- **list-render.awk:** `C["assignees"]` ≠ `""`/`off` turns on the column and the default. `V[id,"assignee"]`
  is compared through `tolower`. The default filter applies only in `render_classic`/`summary`/`digest`
  when there is no `#F assignee` and no epic view (`nv == 0`). Hidden tasks are counted, and the line goes
  through `out_text`. The `me`/`all` values are resolved in `passes()` for `f == "assignee"`: `all` → pass,
  and `me` → compared with `C["me"]`. `list-tasks.sh` rejects `assignee=me` with exit 3 when `--me` is empty.
- **create:** the skill writes `assignee: <me>` into the body it pipes to `allocate-id.sh` in mode `self`.
  No allocate-id change, so the race-critical script is not touched.
- **do / assign:** prose in `commands/do.md` (Start, a new step) and in the new `commands/assign.md`. The
  script does the write, and Claude does the judgement (asking before taking over).
- **Kickoff slice:** a separate task. Only kickoff files: the questionnaire row and `scaffold.sh`'s printf.

## Test specification

New suite `task/scripts/test/assignee.test.sh`. It sources `test/lib.sh`, ends `report assignee`, and is added to
`run.sh` and to the `task/CLAUDE.md` Testing list. Fixture: about six tasks (mine, mine in mixed case, another
person's, unassigned, one in an epic, one closed), plus a git repo with a linked worktree and a no-git dir.

| # | Covers | Case |
|---|--------|------|
| T1 | R2 | No flags vs `--assignees=off`, with hand-written `assignee:` present: output identical to the fixture without the field (list, summary, digest); resolve-config prints no `me=` |
| T2 | R1 | `assignees: "bogus"` → treated as off, one WARNING on stderr |
| T3 | R6 | Mode on: Assignee column after ID/Created and before Status; dropped when no listed task has one; digest prints `assignee:` |
| T4 | R7 | Mode on, me known: mine + unassigned only; `+ N assigned to others — /task list assignee=all`; no line when N = 0; `status=` filter still applies on top |
| T5 | R7 | Mode on, me empty: nothing hidden, unassigned first |
| T6 | R8 | Epic view: tasks of others are shown, column present |
| T7 | R9, Q6 | `assignee=me` (case-insensitive), `assignee=_`, `assignee=all`, `assignee=me,_`; `assignee=me` without `--me` → exit 3 with `needs your id` |
| T8 | R3 | resolve-config `me=`: override wins over `TASK_ME`; `TASK_ME` alone; neither → `me=` empty; lowercased |
| T9 | R4, R15 | Override in git common dir, read from a linked worktree too; no git → `<proj>/.task/me`; `git status --porcelain` unchanged |
| T10 | R4 | Override dir not writable → exit 0, `scope=session` message, nothing written |
| T11 | R12 | assign set / `me` / `_` clears; refuses `all`, empty, `,` `"`; refuses in mode off with a hint; unknown id → error |
| T12 | R13 | `mode self` writes the key, keeps the other keys and `nextId`; a bad mode is refused; a global-registry project is refused |
| T13 | R14 | HOME unset and HOME read-only: T4, T8 and T11 still pass |

Both targets: host and the `task-test` container (busybox awk). Each new assertion group is watched failing
once, by reintroducing the defect (e.g. dropping the default filter, or the `tolower`).

## Implementation

task plugin 1.6.1 → 1.7.0 (plugin.json, marketplace.json, check-descriptions.sh ok).

- `scripts/lib.sh`: `task_assignees_mode`, `task_assignee_norm`, `task_me_file`, `task_me`.
- `scripts/resolve-config.sh`: `with_assignees`, used on both output paths. It normalises `assignees=`
  and adds `me=` when the mode is on. With no key the output is untouched.
- `scripts/list-tasks.sh`: `--assignees=` / `--me=` → `#C` lines. `assignee=me` with no id → exit 3.
- `scripts/list-render.awk`: `aon/asg/ame/by_other/upre`, the shorthands in `passes()`, the default
  narrowing in classic/summary/digest with the `+ N assigned to others` line, the Assignee column, and
  `assignee:` in the digest.
- New `scripts/assign.sh` (set/clear/`--claim`, `me <id>`, `mode …`) and `commands/assign.md` (the one home
  of the "ask for the user's id" procedure, referenced from list/create/do).
- Prose: SKILL.md (description triggers, commands, guardrail, config step with `TASK_ME`), `list.md`,
  `create.md`, `do.md` (Start step 6), `configuration.md`, `task-format.md`, `scripts.md`; `task/CLAUDE.md`
  (layout, Don't regress, Testing); `task/README.md`; root `README.md`; root `CLAUDE.md` vocabulary.
- Tests: `scripts/test/assignee.test.sh`, 93 cases, T1–T13. All 18 suites ALL GREEN on the host and in
  `task-test` (busybox). Watched failing: dropping the default filter (10 red), dropping `tolower` (11 red),
  and normalising when the key is absent (T1 red).

Tech debt: none filed. Known limits, by design and documented: `assign.sh mode` refuses for a
global-registry project (edit the entry by hand), and `epic-dashboard.sh`/task-roadmap do not show the
assignee (out of scope). Noticed, pre-existing and unrelated: SKILL.md frontmatter says `version: 1.5.0`.

## Current State

All steps done, and the code works. Completed 2026-11-16 by `/task finish`. Nothing is committed. Next: PLUG-142 (the kickoff
question), which can now be built against the `assignees` key.

## Release (2026-11-16)

Version bump held back on the user's instruction: several features ship together later. `task` stays at 1.6.1 in
`plugin.json` and `marketplace.json`. The version named under Implementation is the one this change will get
when it is released. Keywords and docs stay as written.

## Review follow-up (2026-11-16)

A code review of the committed change found these; each was first pinned by a test that failed, and a mutant was seen to fail too.
- `/task do` wrote `in-progress` and the active-tasks entry before the claim: the claim is now Start step 3, ahead of
  the epic branch and the status write, and "leave it" stops with nothing written. Epics are claimed like any task;
  their sub-tasks are claimed as the Epic flow runs each one (`commands/do.md`).
- `assignee~me` / `assignee~all` were read as the shorthands; they are shorthands of `=` only (`list-render.awk`, T14).
- An override file holding an unusable id hid `TASK_ME`; `task_me` now falls through (T14).
- `assign.sh me|mode` collided with epics named `me` or `mode`: the settings are now `--me <id>` and `--mode <m>` (T14).
- `task_kv` in lib.sh is the one reader of key=value script output; it replaced copies in assign.sh, id-source.sh,
  allocate-id.sh, renumber.sh, resolve-config.sh and id-git.sh. `with_assignees` matches with `case`, not `| grep -q`.
- Suites ALL GREEN on the host and in `task-test`. No version bump (release held back).
