---
title: crew — display names (spaces) and auto-join from the session title
status: proposed
type: feature
epic: crew-feedback
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

Feedback #1, plus part of #4 (every worker has to run whoami itself).

- **Display name and slug.** `whoami "Max Coordinator"` stores `display=Max Coordinator`
  and derives the crew name (the slug, for example `max-coordinator`) for CREW_AS, files and
  holds. `msg` addresses use the display name, which is what SendMessage needs. The registry
  checks both for uniqueness.
- **Auto-join.** When SessionStart's payload carries `session_title` and the repo has a crew,
  bind the session as a worker under that title, with no manual step. The coordinator role
  stays explicit. If the title is taken by another live session, show the usual join hint
  instead of taking it.
- Skill and README: "use the name peers address you by" now holds as written.

## Acceptance criteria

- [ ] `whoami "Max Coordinator" coordinator` binds `max-coordinator` with that display;
      `msg` headers show `→ Max Coordinator`.
- [ ] A SessionStart payload with `session_title: "Ann Worker"` in a crew repo joins it as a
      worker. Without a title, or in a repo with no crew: nothing changes, and no crew is
      created.
- [ ] A title already held by a live session is not taken.
- [ ] Suites pass on host + docker.

## Notes

Touches `session-start.sh`, as does the PATH slice (`crew` on PATH). Land one before the other,
or put each change in its own function.
