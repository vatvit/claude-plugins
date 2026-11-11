---
title: "crew — mail_ids lists a message's temp file while it is being written, and crew watch dies on it"
status: completed
type: bug
priority: medium
tags: ["crew-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 70 | Tests | done | red first: a `*.tmp.*` file in a mailbox's `new/` is not listed by mail_ids, and watch survives a message that vanishes between listing and reading |
| 90 | Implementation | done | `mail_msg` in inbox.sh; watch.sh skips a vanished message |
| 100 | Tech Debt | skipped | no shortcut taken |
| 110 | Reflection | done | crew/CLAUDE.md, *Mail is a file* rule |

## Problem

`crew watch --wait` (crew 2.5.0) exited 1 while a peer was sending a message:

```
sed: …/.git/crew/mail/<worker>/new/000244.tmp.8076: No such file or directory
watch.sh: line 89: t -  : syntax error: operand expected (error token is " ")
```

`mail_ids` (scripts/inbox.sh:20) lists every file in `new/`, including the temp file a sender writes before renaming
it into place. watch.sh:86–89 takes the first id, the temp file is renamed away, `mail_field … at` returns empty, and
the arithmetic `$(( t - ))` kills the watchdog. The coordinator's watchdog silently stops guarding the crew.

## Scope

- `mail_ids` lists only finished messages (skip `*.tmp.*`), the one place every reader goes through.
- watch.sh treats a message that vanished between listing and reading as gone (skip it), never as a fatal error.

## Tests

- `inbox.test.sh` › *a message still being written is not mail yet*: a `000900.tmp.4242` in `new/` is not listed by
  `inbox`, stays for its sender, and neither the unread notice nor `status` counts it. Red before the fix (inbox
  listed and moved it).
- `watch.test.sh` › *a message being written, or read away mid-pass*: a temp file sorting first no longer makes
  `watch --once` exit 1; and a probe that sources watch.sh with `mail_ids` returning an id with no file (the race:
  read into `cur/` after listing) runs `watch_findings` under `set -euo pipefail` and survives. Both red before.

## Implementation

- `inbox.sh`: `mail_msg <path>` is the one test for a finished message (a file, not `*.tmp.*`); `mail_ids` and
  `mail_count` go through it, so every reader (`inbox`, the hooks, `status`, `watch`) skips a message in flight.
- `mail_field` returns 0 with empty output when the file is gone. The second red showed why it had to: under
  `pipefail` the failing `sed` made the assignment fail and `set -e` killed watch even with a guard after it.
- `watch.sh`: an empty or non-numeric `at=` means the message was read meanwhile; the mailbox is skipped this round.
- Full crew suite green on the host (bash 3.2) and in `crew-test` (bash 5, busybox).
- Unreleased: crew stays at 2.5.0 until the next crew release, like the epic cowork changes already on main.

## Current State

Completed. Nothing open.
