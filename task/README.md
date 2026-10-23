# task

Markdown task management for Claude Code. Tasks are plain `PREFIX-NNN.md` files in your
repo (or wherever you point it) — greppable, diffable, reviewable in a PR, and readable
without this plugin installed.

Runtime-free: pure bash + awk, no dependencies, no network.

## Install

```
/plugin install task@vatvit-plugins
```

## Commands

```
/task create <title>        Create a task (ID allocated atomically)
/task list [filters]        List tasks — filter (by tag too), group, sort; epic views collapse closed work
/task show <id>             Full task content, with its epic's goal for context
/task do <id>               Start work: loads context, runs the current workflow step
/task finish [id]           Run every remaining workflow step to completion
                            (an epic, by id or name: every open sub-task, then the epic)
/task status <id> [status]  Show or change status (cascades to the parent epic)
/task workflow              Show the project's workflow steps
```

IDs accept either form: `4`, `004` or `TASK-004`.

## How it works

- **The workflow table is the state.** Each task carries a `## Workflow` table; the plugin
  reads it to know where the task got to, and updates it as steps complete. There is no
  database and no sidecar file.
- **Epics are documents, not labels.** A `type: epic` task holds the goal, scope, out-of-scope
  and success criteria; sub-tasks reference it by `epic-name`, which is their whole membership
  (the epic never lists them), and inherit that context. An
  `_epic-index.json` gives O(1) epic lookups and is rebuilt, never hand-edited.
- **Tags label tasks across epics.** An epic is a finite batch of work that gets completed; a
  tag says what a task is about and never finishes. An optional `tags: ["performance", "tech debt"]`;
  `/task list tags=performance` filters by it (a repeated `tags=` is AND) and `group=tags`
  groups by it. Claude reuses the tags already in use on its own, and adds a new one only
  with your OK. To tag a backlog, Claude shortlists by keyword (`tags.sh candidates`), judges
  from `/task list digest` (one short block per task, ~1/20 of the files), and writes after
  you approve its proposal.
- **ID allocation is safe across parallel sessions.** `allocate-id.sh` reserves the id and the
  file together under a `mkdir` mutex, computes `max(nextId, highest existing + 1)` so a lost
  counter can never cause a reuse, and creates files with `noclobber`. From a linked git
  worktree it resolves to the main tree, so all worktrees share one sequence and one set of
  task files.

## Configuration

Project-local `.task-config.json` (preferred):

```json
{ "tasksDir": "tasks", "prefix": "PA", "nextId": 1 }
```

Falls back to a global `project-tasks/config.json`, which maps several projects at once —
looked up in `$CLAUDE_CONFIG_DIR` when set (a second Claude account), then in `~/.claude`.
`tasksDir` may be relative, absolute or `~`-prefixed. `nextId` is maintained by the plugin —
never edit it by hand.

The same `.task-config.json` is read by the `task-roadmap` plugin, which charts these task
files as a Gantt roadmap. Neither plugin requires the other.

## Optional: session-storage

If the `session-storage` plugin is installed, the tasks you start are tracked per session, so
active work survives a context reset. Without it every command behaves identically — the
tracking is simply skipped, silently. Nothing here depends on that plugin being present.

## Workflow definitions

A project may define its own steps in `<tasksDir>/_workflow/WORKFLOW.md`, with optional
per-step detail in `_workflow/steps/<name>.md`. Both fall back to
the global `project-tasks/_workflow/` (same lookup). `/task workflow init` seeds a project copy.

## Testing

```
bash scripts/test/epic-dashboard.test.sh   # epic membership, work order, epic-name resolution
bash scripts/test/list-tasks.test.sh       # every documented /task list shape
bash scripts/test/status-session.test.sh   # status writes, epic cascade, active tasks
bash scripts/test/tags.test.sh             # tags decoding, tags= filter, group=tags, tags.sh
bash scripts/test/review.test.sh           # digest, tags.sh candidates, epic hints
bash scripts/test/port.test.sh             # packaging, independence, standalone copy
bash scripts/test/config.test.sh           # global registry, CLAUDE_CONFIG_DIR
bash scripts/test/worktree.test.sh         # a linked git worktree resolves to the main tree
```

Run on the host *and* in a container (`docker run --rm -v "$PWD":/w -w /w bash:5 …`) — the
two targets differ in `diff` output shape and in userland flags, and only running both catches
it. The suite is also expected to pass from a copy of this directory placed outside the
marketplace repo, with no sibling plugins present.

## Provenance

Previously developed at `vatvit/claude-skill-task` as a symlink-installed skill; this plugin
is now the source of truth.
