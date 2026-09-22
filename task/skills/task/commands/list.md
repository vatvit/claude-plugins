# /task list

`list-tasks.sh` does the work — filtering, the `epic=` smart default, grouping, sorting,
collapsing, the Epic column and its id lookups. Call it once and print what it prints.

```
<PLUGIN_ROOT>/scripts/list-tasks.sh <tasksDir> <prefix> [args...]
```

Pass the user's arguments through almost verbatim:

| The user typed | Pass |
|----------------|------|
| `/task list` | see *No arguments* below |
| `/task list 123` / `TASK-123` | `123` — a bare id is an **epic reference**, not a filter |
| `/task list status=proposed` | `status=proposed` |
| `/task list epic=auth group=type` | `epic=auth group=type` |
| `/task list all` / `summary` | `all` / `summary` |
| "only epic auth, no untagged tasks" | `epic=auth --strict-epic` |

Filter syntax (`=`, `~`, `,` for OR, `_` for unset, several fields ANDed) is the script's
`--help`; it is the single source and does not need restating here.

## No arguments

`/task list` means "the work this session is on", and only then everything open.

1. `session-active.sh <tasksDir> <prefix> get` → the `active-tasks` list.
2. For each active id, find its epic: an id that is itself an epic is one; otherwise read
   its `epic` field (`resolve-task.sh`) and resolve that (`resolve-epic.sh`). De-duplicate.
3. Found some → `list-tasks.sh <tasksDir> <prefix> <epic-id> [<epic-id>...] --active=<ids>`,
   then add the line `(use /task list all or /task list <filters> for everything)`.
4. Found none, or no storage helper → `list-tasks.sh <tasksDir> <prefix>` (open tasks only).

## Reading the output

The script prints a finished table. Print it inside a code block, unchanged — do not
re-sort it, re-pad it, add columns or drop rows.

Two lines in it are drill-downs, not decoration; if the user asks for more, run the command
they name:

```
  ✓ 9 closed (8 completed, 1 rejected) — /task list 10 status=completed,rejected
... and 42 more (use /task list status=proposed)
```

## When it exits 1

Only an unresolvable epic reference fails. `resolve-epic.sh`'s stderr distinguishes them:

- `is not an epic` → say so and show that one task instead (`/task show <id>`).
- `Task file not found` / `No epic found` → report it plainly.

Never fall back to listing everything: the user asked about one epic.
