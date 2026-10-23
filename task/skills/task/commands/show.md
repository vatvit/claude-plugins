# /task show

Display a task in full.

1. `resolve-task.sh <tasksDir> <prefix> <id>` — resolves the id and prints metadata plus
   the current workflow step. Exit 1 means no such task.
2. Read the file at the `file=` value and show it.
3. If the output has an `epic=` field, run `resolve-epic.sh <tasksDir> <prefix> <epic-name>`
   and put the parent above the task:

```
Epic: TASK-010 — User Authentication System
  Goal: Implement complete auth system (registration, login, sessions, password reset)
```

The goal line comes from the epic file's `## Goal` section — first line only.

Adding or removing a tag on the task shown goes through `tags.sh` (`references/tags.md`).
