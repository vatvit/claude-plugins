# task-roadmap

Visualise a markdown task set as an **abstract-Gantt roadmap**: tasks scheduled by their
dependencies and estimates, grouped by epic, with the critical path highlighted — rendered as a
single self-contained HTML page. Runtime-free (bash + awk); a bundled hook keeps it in sync as
task files change.

Designed to pair with the `/task` skill: it reads the same `tasks/*.md` files.

## What you get

- **Abstract timeline** — relative units (no calendar dates), scheduled via the critical-path
  method; a task's horizontal offset reflects its dependencies.
- **Grouping by `epic`**, section labels taken from each epic task's title.
- **Critical path** outlined in violet; **status** shown by colour
  (proposed gray · blocked red · in-progress yellow · completed green · rejected dark gray, crossed).
- **Auto-regeneration** on task-file changes via a `PostToolUse` hook.

## Usage

```bash
bash <PLUGIN_ROOT>/scripts/generate.sh [PROJECT_ROOT]
```

`PROJECT_ROOT` defaults to `$CLAUDE_PROJECT_DIR`, else the current directory. Run from a
linked git worktree, it charts the main tree's tasks and writes the roadmap there.

Then open the generated `roadmap.html`. See the bundled **task-roadmap** skill for the full
frontmatter schema (`deps` / `estimate` / `epic`) and the optional `.task-roadmap.json` config.

## Frontmatter

```yaml
---
title: Scene renderer
status: proposed        # proposed | blocked | in-progress | completed | rejected (+ any /task status)
epic: engine            # groups under the "engine" epic; label = that epic task's title
estimate: 8             # abstract effort units (default 1)
deps: [T-006, T-008]    # must-finish-first dependencies
---
```

## Configuration (`.task-roadmap.json`, optional)

```json
{
  "title": "My Project — Task Roadmap",
  "tasksDir": "tasks",
  "outputs": ["tasks/roadmap.html"]
}
```

Runtime-free and offline: the output HTML has no external dependencies.
