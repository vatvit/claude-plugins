---
title: "crew msg: a status kind for progress reports, so a worker does not send progress as a decision"
status: completed
type: feature
priority: medium
epic: crew
created: 2026-11-04 11:48
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 5 | Research | done | |
| 10 | Requirements | done | |
| 30 | Assessment | done | |
| 70 | Tests | done | red first |
| 90 | Implementation | done | |
| 100 | Tech Debt | done | |
| 110 | Reflection | done | |

## Problem

`crew msg` has kinds handoff, decision, stop (scripts/msg.d/core.sh) plus the holds and slots kinds. None of them is a
progress report. In a consumer project (crew 2.4.0, 2026-11-04) workers sent progress as `decision`. msg_decision ends
with "record it in the task file as the coordinator's decision, verbatim.", so the coordinator was told to record
progress as a decision. That pollutes the task files, and real decisions get harder to see.

## Scope

- `crew msg status <text> [--task ID]`: a STATUS head and the text. Its footer says it is for information only, so
  nothing gets recorded.
- The worker role in the crew skill: send progress as `status` and keep `decision` for decisions.
- Check references that list the msg kinds, and the mail hook (hooks/mail.sh) if it treats kinds differently.

## Acceptance

- Red first: `crew msg status` today fails as an unknown kind; after the fix it prints a STATUS message without the
  "record it" line.
- `decision` is unchanged.
- Host and container suites green.

## Origin

Reported by a consumer project's coordinator together with PLUG-103.

## Implementation (2026-11-04)

`msg_status <text> [--task ID]` in msg.d/core.sh: STATUS head, the text, `for information — nothing to record`. SKILL.md worker role: progress as `msg status`, decisions as `msg decision`.

Tests: inbox.test.sh §PLUG-106: kind exists, head, text, no 'record it' line, listed in kinds.

Tech debt: none new.

## Current State

2026-11-04: done. Released in crew 2.5.0 (one release with PLUG-101…107). Host (bash 3.2/BSD) and container (bash 5/busybox) suites ALL GREEN; each fix was reverted once in a throwaway copy and its test went red. Not committed yet: the user decides the commit.
