# Scripts

All at `<PLUGIN_ROOT>/scripts/`, resolved relative to this plugin — never from a pasted
absolute path, and in a hook via `${CLAUDE_PLUGIN_ROOT}`. Pure bash + awk, no dependencies.

Every script takes `--help`, and that text is the authority on its arguments. What follows
is what each is *for*, and the guarantees that are not obvious from the usage line.

| Script | For |
|--------|-----|
| `resolve-config.sh <project-dir>` | project → `tasksDir`, `prefix`, `nextId`, `configFile`, `configScope`, `projectDir`. A linked git worktree resolves to the main tree. Run before anything else. Exit 1 = unconfigured project. |
| `allocate-id.sh <project-dir> [--count N \| --stdin]` | the only sanctioned way to get an id. Prints `TASK-205=/abs/path`. |
| `resolve-task.sh <tasksDir> <prefix> <id>` | one id, or an epic-name (via `resolve-epic.sh`) → `id=`, `file=`, every frontmatter field, the current workflow step and its `step_file=`. Exit 1 = no such task or epic. |
| `read-tasks.sh <tasksDir> <prefix> [flags]` | every task's frontmatter, as JSON or as TSV records. The plugin's only bulk reader. |
| `list-tasks.sh <tasksDir> <prefix> [args]` | the finished `/task list` output — filters, grouping, sorting, collapsing, epic views. |
| `set-status.sh <tasksDir> <prefix> <id> <status>` | status write + parent-epic cascade + `active-tasks` update, in one call. |
| `session-active.sh <tasksDir> <prefix> <action> [id]` | the session's `active-tasks` list. No storage helper configured → `status=unavailable`, exit 0. |
| `resolve-epic.sh <tasksDir> <prefix> <epic-ref>` | epic-name **or** id → epic metadata, same format as `resolve-task.sh`. Exit 1 = not found or not an epic. |
| `update-epic-index.sh <tasksDir> <prefix>` | rebuilds `_epic-index.json`. Idempotent, diff-guarded. |
| `epic-dashboard.sh <tasksDir> <prefix> <epic-ref>` | epic + every sub-task (by `epic:` field) in work order + the `queue` still to work + a recommendation, as JSON. |

## What the guarantees are

**`allocate-id.sh` is the only path to an id**, and its four properties exist because
parallel sessions genuinely raced and destroyed each other's files:

1. the id is computed inside the call, never from a `nextId` read earlier
2. self-healing — `max(nextId, highest existing file + 1)`, so a lost increment or a
   hand-made file cannot cause a reuse
3. never clobbers — `noclobber` (`O_EXCL`); an existing path is skipped, not overwritten
4. serialised — a `mkdir` mutex in `{tasksDir}/.id-alloc.lock`, stale locks broken after 120s

It also persists the new `nextId` to whichever config `resolve-config.sh` resolved.

**`session-active.sh` never requires session-storage.** It is handed `TASK_STORAGE_BIN` and
`TASK_SESSION_ID` by the caller and knows nothing about which plugin provides them. With
neither set it prints `status=unavailable` and exits 0, and `set-status.sh` carries on.

**Membership is the `epic:` field.** `epic-dashboard.sh` joins on it in one `read-tasks.sh` pass,
the same field `/task list <epic>` reads. A `## Sub-tasks` section is prose (`epics.md`).

**Writes are atomic and diff-guarded.** `set-status.sh` and `update-epic-index.sh` write a
temp file and `mv` it, and skip the `mv` when nothing changed, so an unchanged file keeps
its mtime.

## Tests

```
bash scripts/test/epic-dashboard.test.sh   # epic membership, work order, epic-name resolution
bash scripts/test/list-tasks.test.sh       # every documented /task list shape
bash scripts/test/status-session.test.sh   # status writes, cascade, active-tasks
bash scripts/test/port.test.sh             # packaging + a standalone copy with no siblings
```
