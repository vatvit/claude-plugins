# Configuration

`resolve-config.sh <project-dir>` answers all of this; the detail below is for when its
output needs interpreting or a config has to be created.

`<project-dir>` inside a linked git worktree stands for the same place in the main tree
(`projectDir=` in the output): every worktree checks out its own copy of the config and the
tasks folder, and resolving from that copy would give each worktree its own id lock and id
sequence. No git, the main tree itself, and a bare repo's worktree resolve unchanged.

Search order:

1. `<project-root>/.task-config.json` — project-local, preferred
2. `<global>/config.json` — global fallback, keyed by project path

`<global>` is `$CLAUDE_CONFIG_DIR/project-tasks` when Claude Code runs under a non-default
account, then `~/.claude/project-tasks`. Both are searched, in that order, for the registry
and for `_workflow/` files; the first registry that lists the project wins. A new registry
belongs in the first. `resolve-config.sh` reports the one it used as `configFile`.

## Project-local

```json
{
  "tasksDir": "tasks",
  "prefix": "PA",
  "nextId": 519
}
```

`tasksDir` may be relative (resolved against the project root), absolute, or `~`-prefixed.
`nextId` is maintained by `allocate-id.sh` — never edited by hand, never used to derive an
id.

This file is a shared data contract: other tools read `tasksDir` out of it. It stays where
it is and keeps its name.

## Global

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

First run in an unconfigured project: ask for `tasksDir` and `prefix`, then write
`.task-config.json` in the project root.

## Layout

Tasks inside the project (preferred):

```
/path/to/my-project/
├── .task-config.json
├── tasks/
│   ├── _workflow/            # project workflow, overrides the global one
│   ├── _epic-index.json      # generated
│   ├── DOCS-001.md
│   └── DOCS-002.md
└── src/
```

Tasks outside it, several projects in one place:

```
~/.claude/project-tasks/
├── config.json
├── _workflow/                # global default workflow
├── project-a/
│   ├── _epic-index.json
│   └── PROJ-001.md
└── project-b/
    └── TASK-001.md
```

Names starting with `_` are infrastructure, not tasks: `_workflow/`, `_epic-index.json`.
