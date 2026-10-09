---
title: crew — copy rebase reads an empty path when the copy has no changes
status: in-progress
type: bug
epic: crew-feedback
priority: low
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

Found while running the crew on itself (PLUG-041). `copy rebase` on a copy with **no changes**
reads one empty path: `done <<EOF $(copy_changes) EOF` yields one blank line. Then it runs
`cp <copy>/` (a directory) and `git cat-file <sha>:` (a bad file), and reports "1 changed files
carried over". It is harmless today, because the checkout still moves the copy. `apply` already
skips blank paths; `copy_rebase` does not.

Second gap, found while rebasing PLUG-043's copy past PLUG-044, which changed the same lines of
`session-start.sh`. After a worker resolves a conflict inside the copy, `copy rebase` still compares
the old base, the new base and the copy, and refuses again, so "resolve in the copy" is not
actionable. Add `copy rebase <dir> --ours <path>…`: take the copy's file as already resolved against
the new base.

## Acceptance criteria

- [ ] `copy rebase` on an unchanged copy prints no errors and reports 0 files carried over.
- [ ] Regression check in `copy.test.sh`, red on 1.1.x.
- [ ] `copy rebase --ours <path>` accepts the copy's version of a conflicting path. The refusal
      message names the flag, and without it the rebase still refuses.
- [ ] Suites pass on host + docker.
