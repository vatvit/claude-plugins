---
title: crew — silence watchdog: crew watch warns the coordinator
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

Feedback #2b. Nothing noticed 6.5 h of silence.

- **Activity stamps:** every crew hook touches `<state>/seen/<name>`, using builtins only.
- **`crew watch [--once]`:** one line per finding, built for the Monitor tool, `/loop`, or a
  background run by the coordinator. A finding is any of:
  - a session silent for more than `silenceMin` (default 15) while it holds a hold, has a slot,
    or has dirty paths;
  - mail unread for more than `silenceMin`;
  - a stale slot.
  Each finding names the session and the next step.
- **POC: what wakes an idle coordinator?** Candidates are a Monitor event, an `asyncRewake` hook
  (exit 2, the only documented idle wake) and `/loop`. Record what works and make it the
  documented setup in `references/watch.md`.
- `status` shows each session's last activity.

## Acceptance criteria

- [ ] With a fake clock: a silent session that has a hold appears in `watch --once` after
      `silenceMin`, and not before. An idle session with nothing held does not appear.
- [ ] Unread mail older than `silenceMin` is reported, when the mailbox is installed.
- [ ] POC outcome and the recommended coordinator setup are documented.
- [ ] Hooks stay fork-free on the no-crew path.
- [ ] Suites pass on host + docker.

## Notes

The mail check uses the mailbox slice through `load_area`, so this slice also ships without it.
