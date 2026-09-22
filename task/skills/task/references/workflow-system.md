# The workflow system

Each task carries its own workflow table, and that table is the state (see
`task-format.md`). Reading a task therefore tells you where it stands, with no other
bookkeeping: read the file, find the first row that is not `done` or `skipped`, continue
from there, update the row as you go.

`resolve-task.sh` does that reading for you — it reports `current_step`, `current_step_num`,
`current_step_status`, `current_step_key` and, when a definition exists, `step_file`.

## Where definitions live

1. `{tasksDir}/_workflow/` — the project's, and it wins
2. `~/.claude/project-tasks/_workflow/` — the global default

```
_workflow/
├── WORKFLOW.md           # the ordered list of steps
└── steps/                # per-step instructions, optional
    ├── requirements.md
    ├── assessment.md
    └── ...
```

Step files are named for the step, not its number; WORKFLOW.md owns the order.

## WORKFLOW.md

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

Format: `order. step-name - description`. A project may drop steps it has no infrastructure
for, or add its own — read the project's file rather than assuming this list.

## Step detail files

Resolution order for step `<name>`:

1. `{tasksDir}/_workflow/steps/<name>.md`
2. `~/.claude/project-tasks/_workflow/steps/<name>.md`
3. the one-liner in WORKFLOW.md — which is then the whole instruction

A step definition owns its procedure. When one exists, follow it rather than improvising a
better-sounding version.
