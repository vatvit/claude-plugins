---
title: crew — role-aware guard advice; allow git add --dry-run
status: in-progress
type: bug
epic: crew-feedback
priority: medium
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

Feedback #3 and #6.

- The guard's alternatives depend on the role. A **coordinator** is pointed at
  `land --msg-file F -- <paths>`; a **worker** at `msg handoff`; an **each-session** committer at
  `land` for its own paths.
- `git add -n/--dry-run` is allowed, and so is `git add -A --dry-run`: they stage nothing.

## Acceptance criteria

- [ ] A coordinator denied on `git add -A` sees `land`, not "hand off". A worker sees
      `msg handoff`.
- [ ] `git add -A --dry-run` and `git add -n .` are allowed; `git add -A` is still denied.
- [ ] Suites pass on host + docker.
