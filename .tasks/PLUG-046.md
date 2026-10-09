---
title: crew — role-aware guard advice; allow git add --dry-run
status: completed
type: bug
epic: crew-feedback
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | guard_reason in crew/scripts/land.sh; denial texts were role-blind |
| 20 | Requirements | done | acceptance criteria below; scope widened by one found bug (clusters) |
| 30 | Assessment | done | small, one file + its suite, no hot spot |
| 40 | POC | skipped | not needed |
| 50 | Domain | skipped | no new concepts |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | land.test.sh, red first |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | applied to the tree, awaiting land |
| 100 | Tech Debt | done | none added |
| 110 | Reflection | done | see Reflection |

## Description

Feedback #3 and #6.

- The guard's alternatives depend on the role. A **coordinator** is pointed at
  `land --msg-file F -- <paths>`; a **worker** at `msg handoff`; an **each-session** committer at
  `land` for its own paths.
- `git add -n/--dry-run` is allowed, and so is `git add -A --dry-run`: they stage nothing.

## Acceptance criteria

- [x] A coordinator denied on `git add -A` sees `land`, not "hand off". A worker sees
      `msg handoff`.
- [x] `git add -A --dry-run` and `git add -n .` are allowed; `git add -A` is still denied.
- [x] Suites pass on host + docker.

## Context

`guard_reason` in `crew/scripts/land.sh` builds every denial text. The `add` and `commit -a` texts
were the same for every caller ("hand off your paths …; the committer lands them"), so the
coordinator was told to hand off to itself. `git add` had no dry-run exemption.

**Found while testing:** the short-option-cluster patterns (`-[a-zA-Z]*[Au]*`, `-[a-zA-Z]*a*`)
required a letter *before* the flag, so the flag was only caught in second-or-later position.
`git add -Av` and `git add -uv` went through the guard, `git checkout -qf` too, and
`git commit -am` missed the `-a` denial (it was caught later by a less precise one).

## Architecture

Two local helpers inside `guard_reason`, beside `any` and `nonopt`:

- `flag <letters>`: one of the letters anywhere in a short-option cluster
  (`-[L]*` or `-[!-]*[L]*`; a long option never matches). It replaces the hand-written cluster
  patterns in `add`, `commit`, `checkout`, `switch`, `branch` and `clean`.
- `instead`: the one place that says what the caller does instead, by committer mode and role.
  `each-session` → `land … -- <your paths>`; coordinator → `land … -- <paths>`; worker →
  `msg handoff`, the coordinator lands. Used by the `add` and `commit -a` denials.

`git add` returns allowed on `--dry-run` or a cluster with `n`, before the everything-check.
`git clean` uses the same `flag n`, so `git clean -fdn` is allowed as the dry run it is.

## Tests

`crew/scripts/test/land.test.sh`, three new blocks (102 checks), green on the host and in
`crew-test` (bash 5 / busybox). Written first: 8 red on HEAD for the dry-run and role blocks,
5 red for the cluster block.

**Shown failing:** making `instead` skip the coordinator branch fails 4 checks (coordinator
pointed at land / not told to hand off, for `add -A` and `commit -a`). Dropping the
leading-position half of `flag` fails 19, including plain `git add -A`.

## Implementation

`crew/scripts/land.sh` (`flag`, `instead`, the `add` dry-run exemption, cluster checks via
`flag`), `crew/scripts/test/land.test.sh`. No hot spot touched; no version bump here (the
coordinator bumps when landing).

## Tech Debt

None added.

## Reflection

The cluster rule lives in the comment on `flag()`, beside the code that applies it, so no doc
change. Noticed, not fixed here: the pre-bash hook takes the word after `whoami` verbatim, so
`crew.sh whoami NAME; date` leaves no pending id (`NAME;` is not a valid name). Reported to the
coordinator.
