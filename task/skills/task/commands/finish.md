# /task finish

Drive a task to `completed` in one flow. `/task do` pauses between steps; `finish` does not —
it stops only where a decision genuinely needs the user.

## Which task

`/task finish <id>` names it. With no id:

1. `session-active.sh <tasksDir> <prefix> get` → exactly one id, use it.
2. More than one → ask which.
3. No storage helper, or an empty list → `read-tasks.sh <tasksDir> <prefix> --status=in-progress`;
   exactly one, use it; several, ask; none, say so and stop.

## Run

1. `resolve-task.sh <tasksDir> <prefix> <id>`. `type=epic` → show the Epic Dashboard
   (`commands/do.md`) and ask which sub-task to finish; an epic is never finished directly.
2. Confirm the intent, naming what is left:

```
TASK-012: Login / logout endpoints
Remaining steps: assessment, architecture, implementation, tech-debt, reflection
Finish all steps and mark completed?
```

3. On confirmation `set-status.sh <tasksDir> <prefix> <id> in-progress` (harmless if it
   already is), then walk the workflow table top to bottom. For each `—` step: read its
   definition file, do the work, mark the row `done` (or `skipped` with a one-line reason),
   add a section when it produced something worth keeping, and say one line about it before
   moving on.
4. Skippable steps — `bdd`, `poc`, `subtasks` and the like — judge and skip with the reason
   in the Notes column. Do not ask per skip unless it is genuinely ambiguous. Do ask when a
   step needs a real decision: a POC direction, a choice between architectures.
5. All steps `done` or `skipped` → `set-status.sh <tasksDir> <prefix> <id> completed`, which
   also drops it from `active-tasks`. Confirm: `TASK-012 completed. All workflow steps done.`
