# /task status

## Showing

`/task status <id>` with no status → `resolve-task.sh <tasksDir> <prefix> <id>`, then:

```
TASK-001: "Implement auth" — in-progress
```

## Changing

`/task status <id> <status>` — the user asking is what authorises the change; see the
guardrail in `SKILL.md`. Valid: `proposed`, `approved`, `in-progress`, `blocked`,
`completed`, `rejected`.

```
<PLUGIN_ROOT>/scripts/set-status.sh <tasksDir> <prefix> <id> <status>
```

One call does the frontmatter write, the parent-epic cascade and the session's
`active-tasks` update. It prints what it did:

```
id=TASK-012  old=proposed  new=in-progress
epic_id=TASK-010  epic_old=proposed  epic_new=in-progress
active_status=added  active=TASK-010,TASK-012
```

Report every line that appears, because each is a side-effect the user should know about:

```
TASK-012: proposed → in-progress
TASK-010: proposed → in-progress (parent epic of TASK-012)
```

`active_status=conflict` means the session is already on an unrelated task and nothing was
written — that is a question for the user, not a retry. Handle it as `commands/do.md`
describes.

`active_status=unavailable` is normal: no session-storage helper in context. Say nothing.
