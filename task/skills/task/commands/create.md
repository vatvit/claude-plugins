# /task create

## The one atomic step

Pipe the whole task body into `allocate-id.sh`, with `{{ID}}` wherever the id appears:

```
printf '%s' "$BODY" | <PLUGIN_ROOT>/scripts/allocate-id.sh <project-dir> --stdin
```

It prints `TASK-205=/abs/path/TASK-205.md`. Use exactly that id and that path from here on —
it reserved the id under a lock, wrote the file and advanced `nextId` for you. Do not
increment `nextId`, do not compute an id from it, do not write to a path you built yourself.
(`--count N` reserves N empty files in one lock, for creating a batch of sub-tasks.)

Then ask: "Add more details?"

## Tags

Before writing the body, run `tags.sh <tasksDir> <prefix> list`. Put the tags in use that
clearly fit into the body's `tags:` line, without asking; a new tag only with the user's OK.
The rule and the syntax: `references/tags.md`.

## The body

Format and fields: `references/task-format.md`. The minimum is `title` and `status`.

The workflow table goes in with **every step `—` (not started)**. Never pre-mark a step
`done` or `skipped` at creation — steps are decided one at a time when the task is worked
on. Take the step list from the project's WORKFLOW.md (`references/workflow-system.md`).

## Creating an epic

When the user says epic (`/task create EPIC: Auth system`, or asks for one outright):

0. Check it is one: an epic is a finite batch of work that gets completed. A grouping with no
   end ("everything about performance") is a tag — say so (`references/tags.md`).
1. `type: epic` plus an `epic-name` — short kebab-case, e.g. `auth-system`.
2. Ask for Goal, Scope, Out of scope, Success criteria and write them as sections; the
   layout is in `references/epics.md`.
3. Run `update-epic-index.sh <tasksDir> <prefix>` so the name resolves from now on.

## Creating a sub-task

Set `epic: <epic-name>` in the frontmatter. That field is the whole membership: the epic file
never lists its sub-tasks (`references/epics.md`).
