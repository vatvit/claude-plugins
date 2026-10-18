# /task finish

Drive a task to `completed` in one flow. `/task do` pauses between steps; `finish` does not —
it stops only where a decision genuinely needs the user.

## Which task

`/task finish <id>` names it, and so does an epic-name. With neither:

1. `session-active.sh <tasksDir> <prefix> get` → exactly one id, use it.
2. More than one → ask which.
3. No storage helper, or an empty list → `read-tasks.sh <tasksDir> <prefix> --status=in-progress`;
   exactly one, use it; several, ask; none, say so and stop.

## Run

1. `resolve-task.sh <tasksDir> <prefix> <id>` (an id or an epic-name). `type=epic` →
   **Finishing an epic** below.
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

## Finishing an epic

`/task finish <epic>` drives the whole epic: its own remaining rows and every open sub-task. Members are
the tasks whose `epic:` field names it (`references/epics.md`).

1. `epic-dashboard.sh <tasksDir> <prefix> <epic-ref>`. Render the dashboard (`commands/do.md`), then
   confirm once, listing what will run: the epic's remaining planning rows, the `queue` in order (proposed
   sub-tasks included, and say they are proposed), any blocked sub-tasks that will be skipped, and the
   epic's closing rows.

```
TASK-010: User Authentication System [Epic]
Will run: TASK-012 (in-progress), TASK-013 (proposed), TASK-014 (proposed)
Skipped, blocked: TASK-015
Then: tech-debt, reflection on the epic
Finish the epic and mark it completed?
```

2. On confirmation `set-status.sh <tasksDir> <prefix> <epic-id> in-progress`, then work the epic's rows
   before `implementation` as in **Run** step 3. An epic with no sub-tasks runs **Kickoff**
   (`commands/do.md`) here, which needs the user's approval of the breakdown.
3. For each queue head, run **Run** steps 3–5 for that sub-task, without a confirmation of its own. After
   each one, update the epic's "Current State" (done, next) so a context reset resumes from the right
   sub-task, and re-run the dashboard for the next head.
4. Queue empty → the epic's remaining rows. Then `recommend_reason=all-done` →
   `set-status.sh … <epic-id> completed`. Otherwise the epic stays `in-progress`: name the blocked
   sub-tasks and stop.
