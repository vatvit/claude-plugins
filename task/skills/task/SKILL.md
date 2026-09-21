---
name: task
description: Use for task management when user references task IDs (TASK-001, DOCS-004), creates/lists/shows tasks, updates task status, works on tasks, checks workflows, or invokes /task. Also invoke automatically when creating tech debt tickets, subtasks, or any task management during work. Manages task files for planning and tracking project work (storage location configurable per project).
version: 1.0.0
argument-hint: <create|list|show|do|finish|status|workflow> [args]
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# Task Manager

Manage task files for project work planning and tracking.

## Commands

```
/task create <title>           Create new task
/task list [<epic-id>|field=value] [group=field] [sort=field] [summary]  List tasks
                               (bare id = epic → its sub-tasks; no args = active epics' sub-tasks)
/task show <id>                Show task details (id: number or full ID)
/task do <id>                  Start working on task (id: number or full ID)
/task finish [id]              Complete a task by running all remaining workflow steps
/task status <id> [status]     Show or change task status
/task workflow                 Show workflow steps
/task workflow init            Initialize workflow for project
/task                          Show help
```

**ID format:** Accept either number (`004` or `4`) or full ID (`TASK-004`). If number only, prefix from config is used.

Arguments: `$ARGUMENTS`

## Rules

- **Never change task `status` in frontmatter without explicit user approval.** Status changes must be initiated by the user (via `/task status`, `/task do`, or direct request). Do not silently update status while working on a task.
- **Never invent a task ID, and never reuse a `nextId` you saw earlier.** IDs are allocated *only* by `scripts/allocate-id.sh`, called at the moment the file is created. A `nextId` read at the start of a session is stale by the time you create the task — another Claude session may have taken that number in between, and writing to its path destroys their task. Never `Write` to a task path you constructed yourself; only ever write to the path `allocate-id.sh` printed back.

## Session Storage Integration (Optional)

If the `session-storage` plugin is installed, track which tasks are actively being worked on **in the current session**. This survives context resets (`/compact`) and allows instant recall of active work.

**Detection:** Look for the string `SESSION STORAGE PLUGIN:` in the conversation context. If present, session-storage is available — extract the `session_id` and `storage.sh` path from that context string. **If NOT detected, skip all session-storage operations silently.** The task skill works identically without it.

**Storage key:** `active-tasks` — comma-separated full task IDs (e.g., `TASK-001,TASK-003`)

**When to add** (add ID to `active-tasks`):
- `/task do <id>` — add to active-tasks for any status **except** `rejected` or `completed`
- `/task status <id> in-progress` — when status changes to `in-progress`
- **Parent epic** — whenever a sub-task is added to `active-tasks`, also add its parent epic ID (if the task has an `epic` field: run `resolve-epic.sh` to get the epic's task ID, then add it using the same "To add a task ID" procedure — but skip the conflict prompt for the epic itself, just append silently)

**When to remove** (remove ID from `active-tasks`):
- `/task status <id> <new>` — when old status was `in-progress` and new status is anything else
- `/task do <id>` — if task status is `rejected` or `completed`, remove the ID from `active-tasks` if it is present (do not add it)
- **Parent epic is never removed due to a sub-task removal** — only remove an epic from `active-tasks` when the epic task itself is being transitioned away from `in-progress`

**How to update:**

To add a task ID:
1. `get` the `active-tasks` key
2. If result contains `(no value set` → `set` with just the new ID
3. If ID already present → do nothing
4. If existing value contains other ID(s) → check if any active task is the **parent epic** of the requested task:
   - Read the requested task's `epic` field (if present), run `resolve-epic.sh` to get its task ID, compare against each active task ID
   - If a match is found → the user is starting a sub-task while its epic is already active. **Do not ask** — automatically append the new ID and set both in-progress. Briefly mention: "Starting TASK-012 under active epic TASK-010."
   - If no epic match → **ask the user** before proceeding:
     - Show the currently active task(s) and the new task being started
     - Offer three options:
       - **Append** — add the new ID alongside existing ones (work on multiple tasks)
       - **Switch** — change status of previous active task(s) to `on-hold`, set only the new ID as active
       - **Cancel** — do nothing, keep current active-tasks unchanged and abort the `/task do`
     - Based on user choice:
       - Append → append new ID with comma, `set` updated list
       - Switch → update previous task(s) status to `on-hold` in their frontmatter (with user awareness), then `set` with just the new ID
       - Cancel → stop, do not modify `active-tasks` or start the task

To remove a task ID:
1. `get` the `active-tasks` key
2. Parse comma-separated list, remove the target ID, filter empty entries
3. If list is now empty → `clear` the key
4. If list still has entries → `set` with updated list

**After context reset or session resumption:**
When the task skill is first invoked in a session (or after `/compact`), if session-storage is available:
1. Retrieve `active-tasks` key
2. If it has task IDs, mention them: "Session has active tasks: TASK-001, TASK-003"
3. This is more specific than `/task list status=in-progress` — it shows only this session's active work

**When user asks "what am I working on?":**
If session-storage is available, retrieve `active-tasks` first. Optionally read each task file for title. If session-storage is NOT available, fall back to `/task list status=in-progress`.

## Task File Format

**Filename = ID:** `PREFIX-001.md` (zero-padded to at least 3 digits; expands beyond 3 for IDs ≥ 1000)

**Minimal (no workflow):**
```markdown
---
title: Short description
status: proposed
---

Details here.
```

**With workflow table (freshly created — all steps start as `—`):**
```markdown
---
title: Implement logout
status: proposed
type: feature
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Context | — | |
| 10 | Requirements | — | |
| 20 | BDD | — | |
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

User should be able to log out from the app.
```

**In-progress task (steps updated as work progresses via `/task do`):**
```markdown
---
title: Implement logout
status: in-progress
type: feature
priority: high
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Context | done | docs/auth/_index.md; prior art TASK-003 |
| 10 | Requirements | skipped | Simple feature |
| 20 | BDD | skipped | |
| 30 | Assessment | done | Auth module exists |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | in-progress | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

User should be able to log out from the app.

## Assessment

Checked src/auth/ — logout endpoint missing, but auth middleware exists.
```

**Workflow status values:** `—` (not started), `in-progress`, `done`, `skipped`

**Only `title` and `status` frontmatter are required.** Add fields when useful.
Add sections below workflow table only when step produces meaningful output.

## Artifacts Folder

Task file is always `PREFIX-NNN.md` in root (NNN = zero-padded number, at least 3 digits, no upper limit). For complex tasks needing additional files, create a folder with the same name:

```
tasks/
├── TASK-001.md              # Simple task (no artifacts)
├── TASK-002.md              # Task file (always in root)
├── TASK-002/                # Artifacts folder (optional)
│   ├── research.md          # Research notes
│   ├── poc/                 # Proof of concept code
│   └── diagram.png          # Diagrams, screenshots
└── TASK-003.md
```

**Rules:**
- Task file location: always `PREFIX-NNN.md` in root
- Artifacts folder: `PREFIX-NNN/` (same name, no extension)
- Folder is optional — create when needed
- Folder contents are freeform (no enforced structure)

**Workflow tracking (optional):**
Track workflow progress in task body with markdown checklist:
```markdown
## Workflow Progress

- [x] requirements
- [ ] ~~bdd~~ (skipped)
- [x] assessment
- [ ] architecture ← current
- [ ] implementation
```

## Workflow System

### How It Works

1. **Workflow table is embedded in each task file** — the table IS the state
2. **Claude reads task → sees table → knows current state** — no special trigger
3. **Claude updates table as it progresses** — marks steps done/skipped
4. **Add sections only when meaningful** — not forced per step

When asked to work on a task, Claude should:
1. Read the task file
2. Check the workflow table for current state
3. Read workflow definition and step details if needed
4. Continue from where it left off
5. Update table and add sections as work progresses

### Workflow Definition Files

Reference definitions located at:
1. `{tasksDir}/_workflow/` - Project-specific (takes priority)
2. `~/.claude/project-tasks/_workflow/` - Global default

```
_workflow/
├── WORKFLOW.md           # Ordered list of steps
└── steps/                # Step instructions (optional)
    ├── requirements.md
    ├── bdd.md
    └── ...
```

**Note:** Step files use names (not numbers). WORKFLOW.md defines the order.

### WORKFLOW.md Format

```markdown
# Task Workflow

1. context - Orient: epic, docs, prior tasks, code touched; record findings
2. requirements - EARS specifications if needed
3. bdd - Acceptance tests (project-dependent)
4. assessment - Check codebase readiness
5. poc - Prototype risky unknowns (requires approval)
6. domain-lens - DDD constraints/notes
7. architecture - Design decisions
8. tests - Test specifications (project-dependent)
9. subtasks - Break into sub-tickets
10. implementation - Write the code
11. tech-debt - Create debt tickets for shortcuts
12. reflection - Update CLAUDE.md and project docs with lessons learned

Skip steps that don't apply. Each step is a decision point.
```

Format: `order. step-name - description`

### Step Detail Files

If `steps/<name>.md` exists, read it for detailed instructions.

Resolution order:
1. Project's `_workflow/steps/<name>.md`
2. User's default `~/.claude/project-tasks/_workflow/steps/<name>.md`
3. Fall back to one-liner from WORKFLOW.md

### Workflow Commands

**`/task workflow`** - Display workflow steps from WORKFLOW.md

**`/task workflow init`** - Create `_workflow/` in project's tasksDir:
1. Copy global workflow as starting point (if exists)
2. Or create template WORKFLOW.md
3. User can then customize

**`/task workflow step <name>`** - Show detailed instructions for named step

## Configuration

**Config search order:**
1. **Project-local (preferred):** `<project-root>/.task-config.json`
2. **Global (fallback):** `~/.claude/project-tasks/config.json`

**IMPORTANT:** Always run `resolve-config.sh` first to find where tasks are stored for the current project!

### Project-local config (`.task-config.json`)

Place this file in the project root. This is the preferred approach — all task artifacts stay in the project and Claude doesn't need home directory access.

```json
{
  "tasksDir": "tasks",
  "prefix": "PA",
  "nextId": 519
}
```

- `tasksDir` can be relative (resolved against project root) or absolute
- `nextId` is maintained by `allocate-id.sh` — never edit it by hand and never derive an ID from it

### Global config (fallback)

**Location:** `~/.claude/project-tasks/config.json`

Used when no `.task-config.json` exists in the project root. Supports multiple projects:

```json
{
  "projects": {
    "/path/to/project-a": {
      "tasksDir": "~/.claude/project-tasks/project-a",
      "prefix": "TASK",
      "nextId": 1
    },
    "/path/to/project-b": {
      "tasksDir": "/path/to/project-b/tasks",
      "prefix": "DOCS",
      "nextId": 5
    }
  }
}
```

**`tasksDir` can be:**
- External: `~/.claude/project-tasks/project-name` (tasks outside codebase)
- Project-local: `/absolute/path/to/project/tasks` or `./tasks` (tasks in project)
- Any absolute path the user configured

**First run:** If current project not in config, create `.task-config.json` in project root with tasksDir, prefix, and nextId. Ask user for tasksDir and prefix if not obvious.

## Commands Detail

**CRITICAL: Before executing any command:**
Run `<PLUGIN_ROOT>/scripts/resolve-config.sh <project-dir>` to get `tasksDir`, `prefix`, and `nextId` for the current project. This replaces manually reading config.json. Output is key=value pairs, one per line. If the project is not configured, the script exits with error — ask user for config.

### CREATE: `/task create <title>`

1. Allocate the ID and create the file in one atomic step — pipe the full task body into
   `<PLUGIN_ROOT>/scripts/allocate-id.sh <project-dir> --stdin`, using `{{ID}}` wherever the ID appears.
   The script prints `ID=path`; use exactly that ID and path from here on.
   It reserves the ID under a lock, so a concurrent session cannot take the same number,
   and it increments `nextId` for you — do **not** increment it yourself.
2. Ask: "Add more details?"

Never pre-compute the ID from `nextId`, and never write to a task path the script did not return.
Padding is at least 3 digits (`001`, `042`, `999`, `1000` — no upper limit) and is handled by the script.

Workflow table is added with **all steps set to `—` (not started)**. Never pre-mark steps as "done" or "skipped" during creation. Steps are evaluated one by one when the task is worked on (`/task do`).

**Creating an epic:** When the user indicates they want to create an epic (e.g., `/task create EPIC: Auth system` or explicitly says "create an epic"):
1. Set `type: epic` and generate `epic-name` (short kebab-case, e.g., `auth-system`)
2. Prompt the user for: Goal, Scope, Out of scope, Success criteria
3. Add these as sections in the task body (see Epic Tasks section for format)
4. Run `<PLUGIN_ROOT>/scripts/update-epic-index.sh <tasksDir> <prefix>` to update the epic index

**Creating a sub-task for an epic:** When the user creates a task and specifies an epic (or context makes the epic clear):
1. Set the `epic` field in frontmatter to the epic's `epic-name`
2. After creating, remind the user to add the new task ID to the epic's `## Sub-tasks` section

### LIST: `/task list [filters]`

```
/task list                           # Active epics' sub-tasks, else open tasks
/task list 123                       # Bare ID = epic ID → its open sub-tasks, closed ones collapsed
/task list all                       # All tasks including closed
/task list status=proposed           # Filter by specific status
/task list epic=auth                 # Epic "auth" + untagged tasks
/task list epic=_                    # Only tasks without epic
/task list group=priority            # Explicit grouping
/task list sort=priority             # Explicit sorting
/task list summary                   # Counts overview
```

Any frontmatter field works as filter. Parameters can be combined:
```
/task list epic=auth group=type sort=priority  # Epic "auth" + untagged, grouped by type
/task list all group=status                    # All tasks grouped by status
/task list status=proposed,blocked             # Multiple values (OR)
/task list epic=auth,payments                  # Auth OR payments + untagged
/task list type=feature,bugfix priority=high   # (feature OR bugfix) AND high priority
/task list epic~texture                        # Partial: matches textures, mesh-texture, texture-pipeline
/task list title~animation                     # Find tasks with "animation" in title
/task list epic=_                              # Only tasks without epic
```

**Keywords:**
- `all` — include completed and rejected tasks
- `summary` — show counts per status instead of task list
- `group=<field>` — group output by any frontmatter field
- `sort=<field>` — sort within groups (default: by priority then ID)

**Filter syntax:**
- `<field>=<value>` — strict match, exact value
- `<field>=<v1>,<v2>` — match any of the values (OR within field)
- `<field>~<substring>` — partial match, case-insensitive contains (e.g. `epic~texture` matches `textures`, `mesh-texture`, `texture-pipeline`)
- `<field>~<s1>,<s2>` — partial match any of the substrings (OR within field)
- `<field>=_` — tasks where the field is **not set** (e.g. `epic=_`, `priority=_`)
- Multiple fields are combined with AND: `type=feature priority=high,critical`
- Partial match (`~`) works on any string field: `epic~texture`, `title~animation`, `type~bug`

**Bare ID argument — `/task list 123`:**
A lone task ID (`123`, `TASK-123`) is an **epic reference**, not a filter. It means "show this epic's
sub-tasks" — equivalent to `/task list epic=<that epic's epic-name>` **strict** (no `,_`, untagged tasks
are not included; the user asked about one epic).
1. Run `<PLUGIN_ROOT>/scripts/resolve-epic.sh <tasksDir> <prefix> <id>` to get the epic's `epic-name`
2. On success → list with `epic=<epic-name>` strict, and show the epic's own line as a header above the table.
   Read the tasks with `--all` and apply the *Closed sub-tasks — always collapsed* rule below, so the open
   sub-tasks are listed in full and the closed ones are summarised in one line.
3. The script exits 1 in two ways — distinguish by its stderr message:
   - `is not an epic` → say so and show that single task, suggesting `/task show <id>`
   - `Task file not found` / `No epic found` → report it plainly
   In neither case fall back to listing everything.

Other arguments keep their meaning: `epic=auth` is still a filter, `all`/`summary` still keywords. Only a
bare `<number>` or `<PREFIX>-<number>` token is treated as an epic reference.

**Default behavior — `/task list` with no arguments:**
1. Determine the **active epics** first:
   - Retrieve the `active-tasks` key from session-storage (see *Active Task Tracking*)
   - For each active ID: if it is an epic → it is an active epic; otherwise read its `epic` field and
     resolve it via `resolve-epic.sh` → that parent is an active epic. De-duplicate.
2. If one or more active epics were found → show each epic's sub-tasks, one group per epic, exactly as the
   bare-ID form does (strict `epic=<epic-name>`, epic line as the group header). Mark the active task IDs.
   Below the groups add a one-liner: `(use /task list all or /task list <filters> for everything)`.
3. If session-storage is unavailable, `active-tasks` is empty, or no active epic was found → fall back to the
   classic default: open tasks only (excludes `completed` and `rejected`).

**Closed sub-tasks — always collapsed (epic views):**
Applies to every epic group — the bare-ID form, the no-argument active-epic form, and an explicit `epic=`
filter. An epic is read with `--all` so its history is visible, but closed work never crowds out open work:
- **Open sub-tasks** — list them **all**, in the order `in-progress → blocked → approved → proposed`.
  The ">5 rows" collapsing rule does **not** apply to them inside an epic group; an epic is already a
  narrow scope and the user asked for its live work.
- **Closed sub-tasks** (`completed` **and** `rejected`) — never listed as rows, neither of them. Replace
  the whole lot with a single line directly under the epic's open rows:
  ```
  ✓ 11 closed (9 completed, 2 rejected) — /task list <epic-id> status=completed,rejected
  ```
  Name in the parenthesis only the statuses that actually occur, drop the parenthesis when just one does,
  and omit the line entirely when the epic has no closed sub-tasks.
- The epic's own header line keeps the **total** count, with the open count in front:
  `── epic: auth — 5 open / 16 total ──`
- The user can always expand: an explicit `status=completed` (or `status=completed,rejected`) filter lists
  those tasks as normal rows instead of collapsing them.
- The `── no epic ──` group (from the `epic=` smart default) is a normal group: classic default rules,
  closed tasks excluded, not collapsed into a count.

Classic default rules (apply to the fallback and to any filtered list):
- **Auto-grouping:** When >15 open tasks, automatically group by status
- **Group order for status:** `in-progress → blocked → approved → proposed`
- When ≤15 tasks, display as flat table sorted by ID (classic behavior)

**Epic filter — smart default:**
When the user filters by `epic`, Claude should **automatically append `,_`** to include untagged tasks — unless the user explicitly asks to exclude non-epic tasks.
- User writes `epic=auth` → Claude executes as `epic=auth,_` (auth + untagged)
- User writes `epic=auth,payments` → Claude executes as `epic=auth,payments,_`
- User says "only epic auth, no untagged" → Claude executes as `epic=auth` (strict)
- `epic=_` → only tasks with no epic set
- When displayed, epic tasks appear first, then untagged tasks under a separate `── no epic ──` group

**Procedure:**
0. Parse the arguments: a bare ID → *Bare ID argument* above; no arguments → *Default behavior* above
   (both resolve to one or more strict `epic=` filters, then continue from step 1)
1. Read config to get `tasksDir` and `prefix` for current project
2. Run `<PLUGIN_ROOT>/scripts/read-tasks.sh <tasksDir> <prefix> [options]` — outputs task frontmatter as compact JSON to stdout
   - Default: excludes completed/rejected tasks
   - `--all`: include all tasks (use for any epic view — see *Closed sub-tasks — always collapsed* — and when the user explicitly filters by `status=completed`, `status=rejected`, or wants totals across all statuses)
   - `--status=X,Y`: only include tasks with these statuses
3. Apply additional filters to the JSON data:
   - `=` filters: exact match (case-sensitive)
   - `~` filters: substring match (case-insensitive) — check if the field value **contains** the substring
4. For `epic` filter: append `,_` automatically (unless user explicitly excluded untagged)
5. For any epic group: split its tasks into open / closed per *Closed sub-tasks — always collapsed*
6. Determine display mode:
   - If `summary` keyword → show counts table
   - If `group=<field>` or auto-group triggered (>15 tasks) → grouped output
   - Otherwise → flat table sorted by ID

**Sorting rules:**
- Default sort: by priority (`critical → high → medium → low → unset`), then by ID
- `sort=<field>` overrides: sort by that field's value, then by ID
- Sorting applies within each group (or to the whole list if ungrouped)

**Collapsing large groups:**
When a group has more than 5 tasks, show only the top 5 (by sort order) and a summary line **below the table/group** (not as a table row):
```
... and 42 more (use /task list status=proposed)
```
Exception: inside an epic group, open sub-tasks are never collapsed this way and closed ones are always
collapsed — see *Closed sub-tasks — always collapsed*.

**Epic column:**
Show an "Epic" column when any task has `type: epic` or an `epic` field set. Column values:
- Task IS an epic (`type: epic`, or title starts with `EPIC:`): show `[Epic]`
- Task belongs to an epic (`epic: <epic-name>`): run `resolve-epic.sh <tasksDir> <prefix> <epic-name>` to get the epic's task ID and show **only that ID** (e.g., `TASK-010`). Cache the result for the duration of the list command to avoid repeated lookups. If no matching epic task exists, show the raw `epic` value as fallback.
- Task has no epic association: leave empty

**Detecting epic tasks** (checked in order):
1. `type: epic` in frontmatter — preferred
2. Title starts with `EPIC:` — legacy fallback

When an epic task is detected, its `epic` or `epic-name` field value is the key used to match child tasks.

Never show the `epic-name` code in the Epic column — only `[Epic]` or a task ID.

**Output formats:**

*Flat table (≤15 tasks or no grouping):*
```
ID        Status       Priority  Epic      Title
TASK-003  proposed     medium    TASK-010  Add search feature
TASK-005  blocked      high                Fix payment flow
TASK-010  in-progress  high      [Epic]    Implement auth
```

*Grouped (>15 tasks or explicit group=):*
```
── in-progress (3) ──
  TASK-010  high      [Epic]    Implement auth
  TASK-012  high      TASK-010  Fix login bug
  TASK-019  medium              Update dashboard

── blocked (2) ──
  TASK-005  high                Fix payment flow
  TASK-008  medium    TASK-020  Migrate database

── proposed (47) ──
  TASK-023  high      TASK-010  Add SSO support
  TASK-031  high                Rate limiting
  TASK-044  medium              Dark mode
  TASK-045  medium              Export feature
  TASK-046  medium              Search improvements

... and 42 more (use /task list status=proposed)
```

*Epic view (`/task list 10`, `/task list epic=auth`, or the no-argument active-epic form):*
```
── epic: auth — 5 open / 14 total ──
  TASK-010  in-progress  high      [Epic]    Implement auth
  TASK-012  in-progress  high      TASK-010  Add SSO support
  TASK-019  blocked      medium    TASK-010  Session management
  TASK-031  proposed     medium    TASK-010  Password reset
  TASK-044  proposed     low       TASK-010  Auth audit log

  ✓ 9 closed (8 completed, 1 rejected) — /task list 10 status=completed,rejected

── no epic (23) ──
  TASK-005  blocked      high                Fix payment flow
  TASK-008  proposed     high                Rate limiting
  TASK-046  proposed     medium              Search improvements
  TASK-051  proposed     medium              Dark mode
  TASK-052  proposed     low                 Update footer

... and 18 more (use /task list epic=_)
```

*Summary mode (`/task list summary`):*
Compact overview — groups with counts AND top task IDs per group (collapsed).
```
── in-progress (3) ── TASK-001, TASK-012, TASK-019
── blocked (2) ── TASK-005, TASK-008
── approved (5) ── TASK-010, TASK-015, TASK-020, TASK-025, TASK-030
── proposed (47) ── TASK-023, TASK-031, TASK-044, TASK-045, TASK-046 +42
─────────────────
Total open: 57
```

*Summary with group (`/task list summary group=epic`):*
```
── auth (12) ── TASK-001, TASK-012, TASK-019, TASK-031, TASK-044 +7
── payments (8) ── TASK-005, TASK-008, TASK-046, TASK-051, TASK-052 +3
── onboarding (5) ── TASK-010, TASK-015, TASK-020, TASK-025, TASK-030
── (no epic) (32) ── TASK-023, TASK-033, TASK-041, TASK-055, TASK-060 +27
─────────────────
Total: 57
```

`summary` groups by `status` by default. With `group=<field>`, groups by that field. Always shows task IDs (up to 5 per group, then `+N`). Tasks without the field appear as `(no <field>)`.

Show only frontmatter fields that exist. Omit columns where no task has a value (e.g., skip Priority column if no task has priority set).

### SHOW: `/task show <id>`

Display full task content.

1. Run `resolve-config.sh` to get tasksDir and prefix
2. Run `resolve-task.sh <tasksDir> <prefix> <id>` to resolve ID and get metadata
3. Read the full task file (the `file=` value from resolve-task.sh output)
4. Display the content

**Epic context:** If the output includes `epic=<name>`, run `resolve-epic.sh <tasksDir> <prefix> <epic-name>` to get the parent epic's ID and metadata, then display a brief summary:
```
Epic: TASK-010 — User Authentication System
  Goal: Implement complete auth system (registration, login, sessions, password reset)
```

### DO: `/task do <id>`

Load a task and start working on it. This is the main entry point for task execution.

**Steps:**
1. Run `resolve-config.sh` to get tasksDir and prefix
2. Run `resolve-task.sh <tasksDir> <prefix> <id>` — returns all metadata in one call (ID, frontmatter, current workflow step, step definition file path)
3. **If `type=epic`** — run `epic-dashboard.sh <tasksDir> <prefix> <id>` and follow the **Epic Do Flow** below
4. **If `epic=<name>`** — run `resolve-epic.sh <tasksDir> <prefix> <epic-name>` to get the parent epic ID, then read the epic task file for context
5. Read project's CLAUDE.md for project context
6. Display brief summary using the resolve-task.sh output (see format below)
7. Ask user to confirm status change to `in-progress` (if not already). On confirmation: update task frontmatter; if the task has an `epic` field and the parent epic is not already `in-progress`, also update the epic's status to `in-progress` and note it to the user
8. **Session storage:** If session-storage is available:
   - If task status is `rejected` or `completed` — remove the ID from `active-tasks` if present; do **not** add it
   - Otherwise — check the `active-tasks` key. If another task is already active, follow "How to update > To add a task ID": if the active task is this task's parent epic, append silently; otherwise ask the user (append / switch / cancel). If the user chooses cancel, stop here — do not proceed with the task.
9. If `step_file=` was returned by resolve-task.sh, read it for step instructions
10. **Execute the current step** — do the actual work, not just display info
11. When step is done, update workflow table, ask user to confirm, then proceed to next step

**Brief summary format:**
```
TASK-012: Login / logout endpoints
Epic: TASK-010 — User Authentication System
Status: proposed → in-progress?
Type: feature | Priority: high
Current step: 30-assessment

Ready to start assessment. Proceed?
```

**Epic context loading:**
When the task has an `epic` field, read the full epic task file before starting work. The epic provides:
- **Goal & scope** — what are we building and why
- **Out of scope** — boundaries to respect
- **Success criteria** — definition of done at epic level

This context should inform decisions throughout all workflow steps (e.g., architecture choices should align with the epic's overall design).

**Execution guidelines:**
- Work through workflow steps sequentially
- At each step: read step definition → do the work → update table → move on
- Ask user before skipping a step
- If a step produces output (e.g., requirements, architecture notes), add it as a section in the task file

**Planning mode for implementation:**
When the current (or next) step is `implementation` (or `tests`, if it involves writing substantial code), enter Planning mode automatically using the `EnterPlanMode` tool before doing any coding work. No user approval needed — just switch in. Present the plan, get approval via `ExitPlanMode`, then proceed with implementation.

**Using agents:**
Use the Task tool to launch subagents when it improves efficiency:
- **Explore agent** — for codebase research during assessment, architecture, or implementation steps
- **Plan agent** — for designing implementation approach during architecture step
- **Parallel agents** — when multiple independent research questions need answering (e.g., investigating different modules simultaneously)
- **skilled-developer agent** — for implementation of well-defined subtasks
- **test-architect agent** — for test design and implementation during the tests step

Do NOT use agents for trivial operations (reading a single file, small edits). Use them when the work is substantial enough that parallelization or specialization adds value.

**Epic Do Flow:**

When `/task do <id>` targets an epic (`type: epic`), the user wants to **work on the epic as a whole** — not execute the epic file's own workflow steps. Claude should present the epic overview and guide the user to a specific sub-task.

Steps:
1. Run `epic-dashboard.sh <tasksDir> <prefix> <id>` — returns JSON with epic info, all sub-task statuses, and a recommendation
2. **If the epic has no sub-tasks** → follow the **Epic Kickoff Flow** below instead of showing the dashboard
3. Format the JSON output as the **Epic Dashboard**:

```
TASK-010: User Authentication System [Epic]
Status: in-progress | Priority: high

Goal: Implement complete auth system (registration, login, sessions, password reset)

Sub-tasks:
  in-progress (1):
    TASK-012  Login / logout endpoints          high

  proposed (2):
    TASK-013  JWT session middleware             high
    TASK-014  Password reset flow                medium

  completed/rejected (1):
    TASK-011 ✓,

Recommendation: Continue with TASK-012 (in-progress)
```

**Dashboard rules:**
- Group sub-tasks by status: show `in-progress`, `blocked`, `approved`, `proposed` groups expanded (each task on its own line with ID, title, priority)
- Group `completed` and `rejected` into a single collapsed line — just list IDs with ✓ (completed) or ✗ (rejected), since the focus is on remaining work
- If a group is empty, omit it entirely
- **Group display order:** `in-progress → blocked → approved → proposed → completed/rejected`

**Recommendation logic** (pick the first matching rule):
1. If any sub-task is `in-progress` → recommend continuing it (if multiple, pick highest priority, then lowest ID)
2. If any sub-task is `blocked` → mention the blocker and suggest resolving it or picking another task
3. If any sub-task is `approved` → recommend starting it (highest priority first)
4. If any sub-task is `proposed` → recommend it but note it may need approval first
5. If all sub-tasks are `completed`/`rejected` → suggest marking the epic as completed

After showing the dashboard, ask the user which sub-task to work on (pre-select the recommendation). When the user confirms, proceed as a regular `/task do <selected-sub-task-id>`.

**Epic Kickoff Flow** (when epic has no sub-tasks):

This flow turns an empty epic into a planned, actionable set of sub-tasks. The epic stays `in-progress` throughout — it is the parent of all work that follows.

1. **Set epic in-progress:** Update epic status to `in-progress` in frontmatter (if not already). Add the epic ID to `active-tasks` in session-storage (silently, no conflict prompt — this is the first task being started).

2. **Review epic context:** Read the full epic file. Identify what is already defined: Goal, Why, Scope, Out of Scope, Success Criteria. Note any gaps.

3. **Gather project context:** Run the workflow's orientation step for the epic — the step named
   `context` in the project's WORKFLOW.md (some projects name it differently, e.g. `docs-review` or
   `Research`; resolve it the same way as any other step). Its output is the epic's `## Context`
   section. Do not restate the procedure here — the step definition owns it.

4. **Clarify requirements with the user:** Present a short summary of what is known and what is unclear. Ask targeted questions to fill gaps — scope boundaries, priorities, constraints, dependencies. Keep it focused: 2–4 questions max. Wait for user responses.

5. **Enrich the epic file:** Using the gathered context and user answers, update the epic file:
   - Fill in or sharpen the Goal, Scope, Out of Scope, Success Criteria sections
   - Add a `## Context` or `## Notes` section if useful
   - Write changes to the file before proceeding

6. **Propose sub-tasks:** Draft a breakdown of sub-tasks that covers the full epic scope. For each sub-task, propose: title, type, priority, and a one-line description. Present the list to the user as a plan:
   ```
   Proposed sub-tasks for TASK-010 (User Authentication System):

   1. TASK-NNN  Registration endpoint           feature  high
                POST /auth/register, email + hashed password
   2. TASK-NNN  Login / logout endpoints         feature  high
                POST /auth/login, DELETE /auth/session
   3. TASK-NNN  JWT session middleware            feature  high
                Validate token on protected routes
   4. TASK-NNN  Password reset flow              feature  medium
                Email link + token exchange

   Approve this plan, adjust, or add tasks?
   ```

7. **On user approval:** Create each sub-task file using the standard create procedure — one `allocate-id.sh ... --stdin` call per sub-task (or `--count N` up front to reserve the whole block in a single lock), writing each file with the `epic: <epic-name>` field and all steps `—`. Never assume the sub-task IDs are consecutive with anything you saw earlier; use the IDs the script returns. Add a `## Sub-tasks` section to the epic file listing all new task IDs and titles. Run `update-epic-index.sh` to keep the index current.

8. **Suggest next action:** Recommend starting the first sub-task:
   ```
   Sub-tasks created. Ready to start TASK-NNN (highest priority)?
   Run /task do TASK-NNN — the epic TASK-010 stays in-progress alongside it.
   ```
   Do not automatically start the sub-task — wait for the user to invoke `/task do <sub-task-id>`. The epic remains `in-progress` in `active-tasks`; when the user starts a sub-task, both IDs will appear in `active-tasks` (the epic is the parent, so no conflict prompt is shown).

### FINISH: `/task finish [id]`

Run all remaining workflow steps to completion. Unlike `/task do` (which pauses between steps), `finish` drives the task to `completed` in one flow, step by step, only stopping when a step genuinely requires user input.

**Determining the target task (when no id given):**
1. If session-storage is available, retrieve `active-tasks`. If exactly one ID is present, use it.
2. If multiple active-tasks exist, ask the user which to finish.
3. If session-storage is unavailable or empty, run `read-tasks.sh --status=in-progress`. If exactly one in-progress task exists, use it.
4. If multiple in-progress tasks exist, ask the user which to finish.
5. If no in-progress task exists, inform the user and stop.

**Steps:**
1. Run `resolve-config.sh` to get tasksDir and prefix.
2. Run `resolve-task.sh <tasksDir> <prefix> <id>` to get metadata and current workflow state.
3. If `type=epic`, show the Epic Dashboard (same as `/task do`) and ask which sub-task to finish instead — do not attempt to finish an epic directly.
4. Confirm the task and intent with the user:
   ```
   TASK-012: Login / logout endpoints
   Remaining steps: assessment, architecture, implementation, tech-debt, reflection
   Finish all steps and mark completed?
   ```
5. On confirmation, set status to `in-progress` (if not already) and update session-storage accordingly.
6. **Execute each remaining step in sequence:**
   - For each `—` (not started) step in the workflow table (in order):
     a. Read step definition file if available (`step_file` or resolve manually)
     b. Perform the step work
     c. Update the workflow table row to `done` (or `skipped` when skipping)
     d. If the step produces meaningful output, add it as a section in the task file
     e. Brief progress update to the user after each step completes
   - Skippable steps (e.g., `bdd`, `poc`, `subtasks`) should be evaluated and skipped with a one-line reason if not applicable — do not ask the user for each skip unless genuinely ambiguous
   - If a step requires unavoidable user decision (e.g., approving a POC direction, choosing between architectural options), pause and ask — then continue after the response
7. After all steps are `done` or `skipped`:
   - Update task `status` to `completed` in frontmatter
   - Remove task ID from `active-tasks` in session-storage
   - Confirm: `TASK-012 completed. All workflow steps done.`

**Difference from `/task do`:**
- `/task do` works on the current step and asks the user before advancing
- `/task finish` runs all remaining steps autonomously, pausing only when a decision is unavoidable

### STATUS: `/task status <id> [status]`

Show or change task status.

**Without status argument** — show current status:
1. Run `resolve-config.sh` + `resolve-task.sh` to get task metadata
2. Output: `TASK-001: "Implement auth" — in-progress`

**With status argument** — change status:
```
/task status 1 completed
/task status TASK-001 blocked
```
1. Run `resolve-config.sh` + `resolve-task.sh` to get current status
2. Update `status` field in frontmatter of the task file
3. **If new status is `in-progress` and the task has an `epic` field** — also set the parent epic's status to `in-progress` in its frontmatter (if not already). Announce the side-effect: `TASK-010: proposed → in-progress (parent epic of TASK-012)`
4. Display confirmation: `TASK-001: in-progress → completed`
5. **Session storage:** If session-storage is available: if new status is `in-progress` → add task ID to `active-tasks` (which also auto-adds the parent epic per the "When to add" rules); if old status was `in-progress` and new status is anything else → remove task ID from `active-tasks` (do **not** remove the parent epic)

**Valid statuses:** proposed, approved, in-progress, blocked, completed, rejected

### WORKFLOW: `/task workflow`

1. Find WORKFLOW.md (project or global)
2. Display step table
3. Mention available detailed steps

## Directory Layout

**Example 1: External storage (tasks outside codebase)**
```
~/.claude/project-tasks/
├── config.json                   # Projects configuration
├── _workflow/                    # Global default workflow
│   ├── WORKFLOW.md
│   └── steps/
│
├── project-a/                    # External tasks for project-a
│   ├── _workflow/                # Project override (optional)
│   ├── _epic-index.json          # Epic-name → ID index (auto-generated)
│   ├── PROJ-001.md
│   └── PROJ-002.md
│
└── project-b/                    # External tasks for project-b
    ├── TASK-001.md
    └── TASK-002.md
```

**Example 2: Project-local storage (tasks in codebase, preferred)**
```
/path/to/my-project/
├── .task-config.json             # Project-local config (preferred)
├── src/
├── tasks/                        # Tasks stored in project
│   ├── _workflow/                # Project-specific workflow
│   │   ├── WORKFLOW.md
│   │   └── steps/
│   ├── _epic-index.json          # Epic-name → ID index (auto-generated)
│   ├── DOCS-001.md
│   └── DOCS-002.md
└── README.md

~/.claude/project-tasks/
└── _workflow/                    # Global default (fallback)
```

## Epic Tasks

An epic is a **regular task file** (`type: epic`) that describes the whole picture — the goal, scope, and reasoning behind a group of related tasks. It is not just a label or marker; it is a standalone document that any sub-task can reference for context.

### Epic Task Format

```markdown
---
title: User Authentication System
status: in-progress
type: epic
epic-name: auth
priority: high
---

## Goal

Implement a complete authentication system so users can register, log in,
and manage their sessions securely.

## Why

Currently the app has no auth — all endpoints are public. This blocks
multi-tenancy, billing, and personalized features.

## Scope

- Registration (email + password)
- Login / logout
- Session management (JWT)
- Password reset flow

## Out of Scope

- OAuth / SSO (separate epic)
- Role-based access control (follow-up)

## Success Criteria

- Users can register with email and log in
- Sessions expire after 24h
- Password reset works end-to-end

## Sub-tasks

- TASK-011: Registration endpoint
- TASK-012: Login / logout endpoints
- TASK-013: JWT session middleware
- TASK-014: Password reset flow
```

**Key points:**
- Epic file explains **why** and **what** at a high level — sub-tasks handle the **how**
- The `## Sub-tasks` section is informational (manually maintained list of related task IDs)
- **Only list items and table rows count as membership.** A bullet (`- TASK-011: …`), a numbered item
  (`1. TASK-011 …`) or a table row (`| TASK-011 | … |`) makes a task a sub-task; **prose in that section
  does not**. So a sentence such as *"TASK-011 remains a separate epic"* or *"TASK-011's scope shipped
  under TASK-012"* is safe to write there — it is read as commentary, not as a member. Note this means an
  id must appear on the **entry's own line**, not on a wrapped continuation line.
- Epic has its own `status` — tracks overall epic progress
- Epic can have a workflow table too (for planning steps like requirements, architecture)

### Creating an Epic

`/task create <title>` with `type: epic`:
1. Create the task file with `type: epic` and `epic-name` fields
2. Prompt for the epic description (goal, scope, success criteria)
3. The `epic-name` should be a short kebab-case identifier (e.g., `auth`, `onboarding`, `payment-v2`)

### Sub-task ↔ Epic Relationship

- Sub-task references its epic via `epic: <epic-name>` in frontmatter
- When creating sub-tasks for an epic, pre-fill the `epic` field
- The epic's `## Sub-tasks` section should list all related task IDs (kept manually)

## Reserved Fields

| Field | Values |
|-------|--------|
| `status` | proposed, approved, in-progress, blocked, completed, rejected |
| `priority` | low, medium, high, critical |
| `type` | feature, bugfix, refactor, research, docs, epic |
| `epic` | Name of the epic this task belongs to (must match the `epic-name` of a `type: epic` task) |
| `epic-name` | Short identifier for an epic task (used by child tasks in their `epic` field) |

A `type: epic` task **must** have an `epic-name` field. Child tasks reference it via `epic: <epic-name>`.

Add any custom fields as needed.

**Note:** Workflow progress is tracked in task body via `## Workflow Progress` checklist, not in frontmatter.

### Epic Index

The file `{tasksDir}/_epic-index.json` maps epic-name values to task IDs for O(1) lookups:
```json
{"auth":"TASK-010","onboarding":"TASK-020","payment-v2":"TASK-035"}
```

**Maintenance rules:**
- Rebuilt automatically by `update-epic-index.sh` — never hand-edit
- `resolve-epic.sh` uses this index; falls back to a full scan if missing/stale and rebuilds the index in the background
- Run `update-epic-index.sh` after creating or renaming an epic

**Never use `read-tasks.sh` to resolve a single epic** — use `resolve-epic.sh` (for epic-name lookups) or `resolve-task.sh` (when you already have a task ID).

## Scripts

Helper scripts live at `<PLUGIN_ROOT>/scripts/` — the installed `task/` plugin directory,
available to hooks as `${CLAUDE_PLUGIN_ROOT}`. Resolve them relative to the plugin, never
relative to the project being worked on and never from a copied absolute path.

All scripts are pure bash + awk, no dependencies.

**`resolve-config.sh [project-dir]`**
Resolves project configuration. Checks `<project-dir>/.task-config.json` first, falls back to `~/.claude/project-tasks/config.json`. Resolves relative `tasksDir` paths against the project directory, expands `~` in paths.
- Input: project directory (defaults to PWD)
- Output: `tasksDir=... prefix=... nextId=... configFile=... configScope=local|global` (key=value, one per line)
- `nextId` here is informational only — **never allocate an ID from it**, use `allocate-id.sh`
- Exit 1 if no config found or project not registered
- **Use before every command** — replaces manually reading config

**`allocate-id.sh <project-dir> [--count N | --stdin]`**
Atomically allocates task ID(s) and reserves the file(s). **The only sanctioned way to obtain a task ID.**
- `--stdin`: reads the task body from stdin and writes it to the new file, substituting `{{ID}}`
- `--count N`: reserves N ids as empty files (for bulk sub-task creation)
- Output: `TASK-205=/abs/path/TASK-205.md`, one line per allocated id
- Guarantees, in order of importance:
  1. **No stale counter** — the ID is computed inside the call, not from a `nextId` read earlier
  2. **Self-healing** — uses `max(nextId, highest existing file + 1)`, so a lost increment or a
     hand-created file can never cause a reuse
  3. **Never clobbers** — files are created with `noclobber` (O_EXCL); if the path exists it skips forward
  4. **Serialised** — a `mkdir` mutex in `{tasksDir}/.id-alloc.lock` (stale locks broken after 120s)
- Persists the new `nextId` back to whichever config `resolve-config.sh` resolved (local or global)

**`resolve-task.sh <tasksDir> <prefix> <id>`**
Resolves a task ID and extracts all metadata + workflow state in one call.
- Input: tasksDir, prefix, ID (number `4` or full `TASK-004`)
- Output (key=value, one per line):
  - `id`, `file` — resolved ID and full file path
  - All frontmatter fields (`title`, `status`, `type`, `priority`, `epic`, etc.)
  - `current_step`, `current_step_num`, `current_step_status`, `current_step_key` — if workflow table exists and has a non-done step
  - `step_file` — path to step definition file if found (checks project then global `_workflow/steps/`)
- Exit 1 if task file not found
- Strips YAML quotes from values; only parses tables inside `## Workflow` section

**`read-tasks.sh <tasksDir> <prefix> [--all|--status=X,Y]`**
Reads all task frontmatter, outputs compact JSON array. Used by `/task list`.
- Default: excludes `completed` and `rejected` tasks
- `--all`: includes all tasks regardless of status
- `--status=X,Y`: only includes tasks matching listed statuses
- Output: `[{"id":"TASK-001","title":"...","status":"...","priority":"...",...},...]`

**`update-epic-index.sh <tasksDir> <prefix>`**
Rebuilds the epic-name → task-ID index. Scans all `PREFIX-*.md` files for `type: epic` + `epic-name`, writes `{tasksDir}/_epic-index.json`.
- Idempotent — full rebuild each time, safe to run anytime
- Run after creating or renaming an epic
- Output file: `{"auth":"TASK-010","rigging":"TASK-320"}`

**`resolve-epic.sh <tasksDir> <prefix> <epic-ref>`**
Resolves an epic reference to a task ID and extracts metadata. Accepts three input forms:
- Numeric ID (`459`) or full ID (`TASK-459`) → delegates to `resolve-task.sh`, verifies `type=epic`
- Epic-name (`2d-char-anim`) → looks up `_epic-index.json` for O(1) resolution; falls back to scan if index is missing/stale and rebuilds index in background
- Output: same `key=value` format as `resolve-task.sh`
- Exit 1 if not found or not an epic
- Emits `WARN` to stderr when falling back to scan

**`epic-dashboard.sh <tasksDir> <prefix> <epic-id>`**
Gathers epic overview + all sub-task statuses + recommendation. Used by `/task do` on epics.
- Input: tasksDir, prefix, epic ID (number or full)
- Reads epic file, extracts goal, reads each sub-task from `## Sub-tasks` section — counting **only list
  items and table rows** (see *Epic Task Format* above), de-duplicated. Prose there is commentary.
- Regression tests: `bash <PLUGIN_ROOT>/scripts/test/epic-dashboard.test.sh` (11 cases, no dependencies)
- Output: JSON object with `id`, `title`, `status`, `priority`, `goal`, `subtasks[]` (each with `id`, `title`, `status`, `priority`), `recommend` (task ID), `recommend_reason` (`in-progress`|`blocked`|`approved`|`proposed`|`all-done`)
- Exit 1 if file not found or `type` is not `epic`

## References

- **`references/workflow-guide.md`** - Detailed workflow documentation
- **`examples/TASK-001.md`** - Example task file
