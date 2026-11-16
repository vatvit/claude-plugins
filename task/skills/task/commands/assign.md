# /task assign

Who a task is for: a person, by an email or any name. It's opt-in per project. The config key
`assignees` is `off` by default, which keeps a solo project's tasks and lists exactly as they
were. It is a different thing from crew's task ownership, which is about *sessions*.

| `assignees` | Meaning |
|-------------|---------|
| `off` (or absent) | No assignees. This command refuses until the mode is turned on. |
| `unassigned` | New tasks start without an assignee. |
| `self` | New tasks go to whoever creates them. |

## Assigning

`/task assign <id> [who]`: the user asking is what authorises it, as with status (the
guardrail in `SKILL.md`). `who` is an id, `me` (the default) or `_` (unassigned).

```
<PLUGIN_ROOT>/scripts/assign.sh <projectDir> <id> [who|me|_]
```

It prints `id= old= new=`. Report `TASK-012: ann → bob`, or `unassigned → you` when it went to the user.
Exit 1 with "assignees are off" → tell the user, and offer to turn them on (below).

## Turning it on or off

When the user asks ("turn on assignees", "this is a team project"), ask which mode they want, `unassigned`
or `self`, then:

```
<PLUGIN_ROOT>/scripts/assign.sh <projectDir> --mode off|unassigned|self
```

It edits `.task-config.json`, which is committed, so it is the team's choice. Say so.

## The user's id: "me"

`resolve-config.sh` prints `me=` when assignees are on. That is the per-project override if one is
set, otherwise the `TASK_ME` you passed (the Claude account email). An empty `me=` means it is unknown.
**Ask only when a command needs it:** `assignee=me` in a list, `/task do`, `/task assign` without
`who`, or `/task create` in mode `self`. A script that needs it and lacks it exits 3 with `needs your id`.
A plain `/task list` never asks.

When it is needed:
1. Ask the user how they want to be identified in this project (an email or a name).
2. `assign.sh <projectDir> --me <id>` saves it outside version control (the git common dir, or
   `<project>/.task/me` without git). `scope=session — … not writable` means it could not be saved there.
3. With the session-storage helper in context, also `set <session> task-me <id>`. In later commands, pass
   `TASK_ME=<stored id>` when the account email is absent.
4. Retry the command that needed it.

The same question is how the user's id gets set when no account email is in context (API key, Bedrock,
Vertex, other hosts). A new session that has lost the id simply asks again.
