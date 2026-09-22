# Epics

An epic is a regular task file with `type: epic` and an `epic-name`. It is a document, not
a label: it carries the goal, the scope and the reasoning that its sub-tasks inherit.

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

## Sub-tasks

- TASK-011: Registration endpoint
- TASK-012: Login / logout endpoints
```

An epic has its own `status`, and may have its own workflow table for planning steps.

## What makes a task a sub-task

Two things, kept in step by hand:

- the sub-task's frontmatter: `epic: auth`
- an entry in the epic's `## Sub-tasks` section

**Only list items and table rows are entries.** A bullet (`- TASK-011: …`), a numbered item
(`1. TASK-011 …`) or a table row (`| TASK-011 | … |`) makes a task a member; prose does not.
So "TASK-011 remains a separate epic" or "TASK-011's scope shipped under TASK-012" is safe
to write there — it reads as commentary. The id must be on the entry's own line, not on a
wrapped continuation.

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
