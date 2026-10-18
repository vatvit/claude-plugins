# /task do

Load a task and work on it. This is the main entry point for execution.

## Start

Invoking `/task do` *is* the go-ahead. Do not ask whether to start the task or whether to
set it `in-progress` — just do it. The only question this section may ask is the
`active_status=conflict` one in step 5.

1. `resolve-task.sh <tasksDir> <prefix> <id>` — id, file, frontmatter, the current workflow
   step and its `step_file=` if one exists. `<id>` may also be an epic-name; an unknown one
   fails with the resolver's error: report it and stop.
2. If the task's status is `rejected` or `completed`, do not start it: drop it from the
   list with `session-active.sh <tasksDir> <prefix> remove <id>` and tell the user. Stop.
3. `type=epic` → this is the **Epic flow** below, not a plain workflow run.
4. `set-status.sh <tasksDir> <prefix> <id> in-progress` — without asking, and harmless if
   it already is. It writes the status, cascades to the parent epic and updates
   `active-tasks` in one call — report its output as `commands/status.md` describes.
5. If it prints `active_status=conflict`, the session is on an unrelated task. Ask, and do
   exactly what the user picks:
   - **Append** — `session-active.sh <tasksDir> <prefix> add <id> --force`
   - **Switch** — `session-active.sh <tasksDir> <prefix> set <id>`: this becomes the only
     active task. It does **not** change the other tasks' status; if the user wants them
     parked as well, `blocked` is the status for it (`on-hold` is not a valid status).
   - **Cancel** — stop here. Do not work the task; the status change stays, so say so and
     offer to put it back.
   A sub-task whose parent epic is the active task is not a conflict; the script appends it
   silently and says `epic=`.
6. `epic=<name>` → `resolve-epic.sh` and read the epic file. Goal, Scope, Out of Scope and
   Success Criteria constrain every step that follows, architecture most of all.
7. Read the project's CLAUDE.md.
8. Show the summary, then go straight on to **Work the step**:

```
TASK-012: Login / logout endpoints
Epic: TASK-010 — User Authentication System
Status: proposed → in-progress
Type: feature | Priority: high
Current step: 30-assessment
```

## Work the step

Read `step_file=` if there is one; otherwise the one-liner in WORKFLOW.md is the whole
instruction (`references/workflow-system.md`). Then **do the step** — the point is the work,
not a report about it. When it is done, update that row in the task's workflow table, add a
section to the task file if the step produced something worth keeping, and ask before moving
to the next step. Ask before skipping a step.

When the current or next step is `implementation` — or `tests`, if substantial code —
enter planning mode (`EnterPlanMode`) first, without asking; present the plan, get approval
via `ExitPlanMode`, then write the code.

Use subagents when the work is big enough to pay for them: exploration during assessment or
architecture, parallel research on independent questions, `skilled-developer` for a
well-defined sub-task, `test-architect` for the tests step. Not for a single file read.

## Epic flow

`/task do <epic>` (an epic id, number or epic-name) means "work this epic": its own planning, every open
sub-task, then its own closing steps. A sub-task belongs to the epic through its `epic:` field alone
(`references/epics.md`).

```
<PLUGIN_ROOT>/scripts/epic-dashboard.sh <tasksDir> <prefix> <epic-ref>
```

It returns the epic, every sub-task with its status and priority, a `queue` (the open, unblocked sub-tasks
in work order: in-progress, approved, proposed, then priority, then id), and a `recommend` with a
`recommend_reason`.

1. `set-status.sh <tasksDir> <prefix> <epic-id> in-progress` and read the epic file. Its Goal, Scope, Out
   of Scope and Success Criteria constrain every sub-task.
2. Show the dashboard (below).
3. **Planning.** Work the epic's own workflow rows *before* `implementation`, the same way as a task's
   (**Work the step**). Its `subtasks` step is **Kickoff** below when the epic has no sub-tasks yet. Rows
   already `done` are left alone.
4. **Sub-tasks.** Take the head of `queue` and run it as `/task do <that id>`, pausing before each of its
   steps. When it is `completed`, update the epic's "Current State" (which sub-task is done, which one is
   next), re-run the dashboard and go straight on to the next queue head without asking. Blocked sub-tasks
   are never in the queue; name them when the queue runs out.
5. **Closing.** Queue empty → work the epic's remaining rows (tech-debt, reflection). The epic is completed
   only when `recommend_reason=all-done` and the user agrees; with blocked sub-tasks left it stays
   `in-progress`, and say why.

Render the dashboard grouping `in-progress → blocked → approved → proposed`, each task on its own line;
fold `completed` and `rejected` into one line of ids with ✓ / ✗, since the focus is the remaining work.
Omit empty groups.

```
TASK-010: User Authentication System [Epic]
Status: in-progress | Priority: high

Goal: Implement complete auth system (registration, login, sessions, password reset)

Sub-tasks:
  in-progress (1):
    TASK-012  Login / logout endpoints           high

  proposed (2):
    TASK-013  JWT session middleware             high
    TASK-014  Password reset flow                medium

  completed/rejected (1):
    TASK-011 ✓

Next: TASK-012 (in-progress), then TASK-013, TASK-014
```

## Kickoff: an epic with no sub-tasks

Turns an empty epic into a planned set of tasks. It is the epic's `subtasks` step, or the whole of
planning when the epic has no workflow table.

1. Read the epic file; note which of Goal / Why / Scope / Out of Scope / Success Criteria
   are missing or vague.
2. Run the workflow's orientation step for the epic: the step named `context` in the
   project's WORKFLOW.md (some projects name it differently). Its output becomes the epic's
   `## Context`. The step definition owns the procedure; do not improvise one.
3. Ask the user 2–4 targeted questions about the gaps: scope boundaries, priorities,
   constraints, dependencies. Wait for the answers.
4. Write the sharpened sections back to the epic file before going on.
5. Propose the breakdown (title, type, priority and one line each) and get approval:

```
Proposed sub-tasks for TASK-010 (User Authentication System):

1. Registration endpoint            feature  high
   POST /auth/register, email + hashed password
2. Login / logout endpoints          feature  high
   POST /auth/login, DELETE /auth/session

Approve this plan, adjust, or add tasks?
```

   Do not show ids you have not been given — they do not exist until step 6.
6. On approval create each one (`commands/create.md`) with `epic: <epic-name>` set. That field is
   the whole membership: do not list the ids in the epic file.
7. Continue the Epic flow with the sub-tasks.
