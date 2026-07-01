---
name: task-roadmap
description: Use to generate or refresh a visual task roadmap — an abstract Gantt chart (scheduled by dependencies and estimates, grouped by epic, with the critical path highlighted) rendered as a self-contained HTML page from a markdown task set. Activate on "generate the roadmap", "show the task gantt", "update the roadmap", "task timeline", or after changing task dependencies/estimates. Complements the /task skill.
version: 1.0.0
---

# Task Roadmap

Render a markdown task set (the `tasks/*.md` files managed by the `/task` skill) as a
**self-contained abstract-Gantt HTML page** — no build, no network, opens via `file://`.

- **Abstract Gantt** — tasks scheduled by their dependencies and `estimate` into *relative*
  time units (no calendar dates, no "today"). A task starts after its predecessors finish,
  so horizontal offset conveys the dependency structure.
- **Grouping by epic** — rows are grouped under their `epic` (the section label is the epic
  task's title). Tasks with no epic fall under `—`.
- **Critical path** — the longest estimate-weighted chain, always outlined in violet.
- **Status colour** — `proposed` gray · `blocked` red · `in-progress` yellow ·
  `completed` green · `rejected` dark gray (crossed out).

## Generate

Runtime-free (pure bash + awk). Invoke the plugin script:

```bash
bash <PLUGIN_ROOT>/scripts/generate.sh [PROJECT_ROOT]
```

`PROJECT_ROOT` defaults to `$CLAUDE_PROJECT_DIR` (else the current directory). The page is
regenerated automatically by the bundled hook whenever a task file changes — so manual runs
are only needed for the first build or after editing the template.

## Task frontmatter it reads

Add these optional fields to `tasks/*.md` (the `/task` skill's files):

| Field | Example | Meaning |
|---|---|---|
| `deps` | `deps: [T-005, T-008]` | Tasks that must finish first — drives the schedule (bar offset). Unknown IDs ignored. |
| `estimate` | `estimate: 5` | Abstract effort units — bar length and critical-path weight. Defaults to 1. |
| `epic` | `epic: engine` | Groups the task under an epic (native `/task` field). Section label = that epic task's title. |

`status` picks the colour. A `type: epic` task is **not charted** — it only supplies its
section label via its title. Units are **abstract**: ordering and relative size, not durations.

## Configuration (optional)

`<root>/.task-roadmap.json`:

```json
{
  "title": "My Project — Task Roadmap",
  "tasksDir": "tasks",
  "outputs": ["tasks/roadmap.html"]
}
```

- `title` — page heading (default `Task Roadmap`).
- `tasksDir` — where task files live (defaults to `.task-config.json`'s `tasksDir`, else `tasks`).
- `outputs` — one or more paths to write (all regenerated together; default `<tasksDir>/roadmap.html`).

## Auto-regeneration

The plugin ships a `PostToolUse` hook (`hooks/hooks.json` → `scripts/regenerate-hook.sh`) that
regenerates the output whenever an `Edit`/`Write`/`MultiEdit` touches a task file under the
tasks dir (excluding `_workflow/`). No per-project setup needed — enabling the plugin is enough.
