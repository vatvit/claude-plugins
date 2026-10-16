---
name: task
description: Use for task management when user references task IDs (TASK-001, DOCS-004), creates/lists/shows tasks, updates task status, works on tasks, checks workflows, or invokes /task. Also invoke automatically when creating tech debt tickets, subtasks, or any task management during work. Manages task files for planning and tracking project work (storage location configurable per project).
version: 1.1.0
argument-hint: <create|list|show|do|finish|status|workflow> [args]
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# Task Manager

Task files are markdown with YAML frontmatter, one file per task, in a directory this
skill resolves per project. The file *is* the state — there is no database.

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
/task                          Show this help
```

**ID format:** either a number (`004` or `4`) or a full ID (`TASK-004`). A bare number is
completed with the project's prefix.

## Guardrails

These override anything a command file says, and no script enforces them — they are
judgement calls that cost real work when got wrong.

- **Never invent a task ID, and never reuse a `nextId` you saw earlier.** IDs come only
  from `allocate-id.sh`, called at the moment the file is created. A `nextId` read at the
  start of a session is already stale — another session may have taken it, and writing to
  that path destroys their task. Never `Write` to a task path you constructed yourself;
  only to the path `allocate-id.sh` printed back.
- **Never change a task's `status` without the user asking.** `/task status`, `/task do`
  and `/task finish` change status because the user invoked them. Nothing else does, and
  never silently while working.
- **A task in flight is append-only.** Before implementation starts the task text can be
  reshaped freely; after it, the file is history — add sections, do not rewrite them.
- **Keep "Current State" current.** It is what the next session (or the next context)
  starts from: build status, known issues, next action.

## Every command starts here

```
<PLUGIN_ROOT>/scripts/resolve-config.sh <project-dir>
```

It prints `tasksDir=`, `prefix=`, `nextId=`, `configFile=`, `configScope=`, `projectDir=`. Exits 1 when the
project has no config — then ask the user for `tasksDir` and `prefix` and write
`.task-config.json` in the project root. `nextId` in that output is informational; allocating
from it is the first guardrail above.

**In a git worktree, the task files are the main tree's.** The scripts map a linked worktree
to the main tree, so their output names paths outside your working directory. Read and write
task files only at the absolute paths the scripts print (`tasksDir=`, `allocate-id.sh`'s
`ID=path`), never at the same relative path under the worktree — that is a stale copy.

`<PLUGIN_ROOT>` is this plugin's directory — resolve the scripts relative to this skill file,
never from a pasted absolute path.

## Then read the command file

| Command | Read |
|---------|------|
| `create` | `commands/create.md` |
| `list` | `commands/list.md` |
| `show` | `commands/show.md` |
| `do` | `commands/do.md` |
| `finish` | `commands/finish.md` |
| `status` | `commands/status.md` |
| `workflow` | `commands/workflow.md` |

Read exactly the one being run. Each is self-contained for its command; where it needs a
rule that other commands share, it names the reference file to read.

## Session storage (optional)

If the context contains the string `SESSION STORAGE PLUGIN:`, a key-value helper scoped to
this session is available. Extract the storage script path and the session id from it, and
pass them to the task scripts as environment variables:

```
TASK_STORAGE_BIN=<path to that script> TASK_SESSION_ID=<session id> \
  <PLUGIN_ROOT>/scripts/session-active.sh <tasksDir> <prefix> get
```

`session-active.sh` keeps the `active-tasks` list — which tasks this session is working on,
surviving `/compact`. With no helper in context, pass nothing: every script prints
`status=unavailable` and carries on. Most installs are in that state, and no command may
depend on it.

When the skill is first used in a session, `get` the list and, if it is non-empty, say so:
"Session has active tasks: TASK-001, TASK-003". That is also the answer to "what am I
working on?" — falling back to `/task list status=in-progress` when there is no helper.

## References — read when the command file sends you

| File | Holds |
|------|-------|
| `references/task-format.md` | Task file format, workflow table, artifacts folder, reserved fields |
| `references/epics.md` | Epic file format, sub-task ↔ epic relationship, the epic index |
| `references/workflow-system.md` | How the workflow table drives work, step definition files |
| `references/configuration.md` | Config resolution, directory layouts |
| `references/scripts.md` | What each script does, its arguments and guarantees |
| `references/workflow-guide.md` | Extended workflow documentation |
| `examples/TASK-001.md` | An example task file |
