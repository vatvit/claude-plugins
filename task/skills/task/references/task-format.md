# Task file format

Filename is the id: `PREFIX-001.md`, zero-padded to at least three digits and wider beyond
999 (`PLUG-1000.md`). The file lives in the root of `tasksDir`, always.

Only `title` and `status` are required. Add fields when they earn their place.

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
| 10 | Context | — | |
| 20 | Requirements | — | |
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

The steps and their numbers come from the project's WORKFLOW.md, so this table is an
example, not a fixed list.

## The workflow table is the state

Nothing else records how far a task got. Statuses in it: `—` (not started), `in-progress`,
`done`, `skipped`. The current step is the first row that is neither `done` nor `skipped` —
which is exactly what `resolve-task.sh` reports as `current_step`.

As work progresses, the row changes and a section may appear below the table:

```markdown
| 30 | Assessment | done | Auth module exists |
| 90 | Implementation | in-progress | |

## Assessment

Checked src/auth/ — logout endpoint missing, but auth middleware exists.
```

Add a section only when the step produced something worth keeping. An empty section per
step is noise.

## Reserved fields

| Field | Values |
|-------|--------|
| `status` | proposed, approved, in-progress, blocked, completed, rejected |
| `priority` | low, medium, high, critical |
| `type` | feature, bugfix, refactor, research, docs, epic |
| `epic` | the `epic-name` of the epic this task belongs to |
| `epic-name` | an epic's own short identifier, referenced by its children |

Any other field is free — and any of them can be filtered on by `/task list`.

## Artifacts folder

A task needing more than one file gets a directory beside it, same name without the
extension. Contents are freeform.

```
tasks/
├── TASK-002.md              # the task file — always in the root
├── TASK-002/                # optional artifacts
│   ├── research.md
│   ├── poc/
│   └── diagram.png
└── TASK-003.md
```

## A legacy form you may still meet

Older tasks track progress as a checklist in the body instead of a table:

```markdown
## Workflow Progress

- [x] requirements
- [ ] ~~bdd~~ (skipped)
- [x] assessment
- [ ] architecture ← current
```

Read it when it is there, but do not create it: `resolve-task.sh` finds the current step
from the table, and two records of the same state disagree sooner or later.
