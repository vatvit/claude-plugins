# Epics

An epic is a regular task file with `type: epic` and an `epic-name`. It is a document, not
a label: it carries the goal, the scope and the reasoning that its sub-tasks inherit. An epic
is finite and gets completed; a topic that never ends is a tag (`tags.md`, *A tag is not an epic*).

```markdown
---
title: User Authentication System
status: in-progress
type: epic
epic-name: auth
priority: high
---

## Goal

Implement a complete authentication system so users can register, log in,
and manage their sessions securely.

## Why

Currently the app has no auth — all endpoints are public. This blocks
multi-tenancy, billing, and personalized features.

## Scope

- Registration (email + password)
- Login / logout
- Session management (JWT)
- Password reset flow

## Out of Scope

- OAuth / SSO (separate epic)
- Role-based access control (follow-up)

## Success Criteria

- Users can register with email and log in
- Sessions expire after 24h
- Password reset works end-to-end
```

An epic has its own `status`, and may have its own workflow table. Working the epic
(`/task do` or `/task finish` on it) runs that table's rows before `implementation`, then the
sub-tasks, then the remaining rows (`commands/do.md`, Epic flow).

## What makes a task a sub-task

Its frontmatter field `epic: <epic-name>`, and nothing else. The epic never lists its sub-tasks:
a list is the same fact stored a second time, kept in step by hand, and once the two disagree no reader
knows which is right. `/task list <epic>`, the Epic Dashboard and `/task do`/`finish` on an epic all
read the field.

Older epics may still carry a `## Sub-tasks` section. It is prose now: an id listed there and not
carrying the `epic:` field is not a member. Leave the section as history; do not add one.

## Detecting an epic

1. `type: epic` in frontmatter — the real rule.
2. A title starting with `EPIC:` — legacy fallback, still honoured.

Either way, the task's `epic-name` is the key its children carry in their `epic` field.

## The epic index

`{tasksDir}/_epic-index.json` maps epic-name to task id for O(1) lookups:

```json
{"auth":"TASK-010","onboarding":"TASK-020","payment-v2":"TASK-035"}
```

Rebuilt by `update-epic-index.sh`, never hand-edited. `resolve-epic.sh` reads it and falls
back to a scan (rebuilding the index in the background) when it is missing or stale. Run
`update-epic-index.sh` after creating or renaming an epic.

Resolving one epic is `resolve-epic.sh` (by name) or `resolve-task.sh` (by id) — never a
`read-tasks.sh` scan.
