---
title: "session-storage — hardening: jq dependency, stat order, unchecked session id and key used as paths, hooks untested"
status: proposed
type: bugfix
priority: medium
tags: ["session-storage-plugin"]
created: 2026-11-11 18:59
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 30 | Assessment | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

Found while doing PLUG-122 (2026-11-11). It is out of that task's scope, which covered only a plain failure when the storage dir can't be written.
Each item breaks a rule in root `CLAUDE.md` or is a defect:

1. **`jq` is required** by both hooks (`capture-session.sh`, `cleanup-session.sh`). The repo rule is pure bash + awk, and a host without
   jq silently gets no session id. Parse `session_id` with awk, as the other plugins do.
2. **`stat -f %m` is tried before `stat -c %Y`** (`storage.sh` list). On busybox, `stat -f` prints filesystem status and fails, which is the trap
   root `CLAUDE.md` *File mtime* describes. Swap the order.
3. **`session_id` and `key` are used as path parts unchecked** (`storage.sh` set/get/clear, the hooks). A key such as `../../x` writes
   outside the storage dir, and `clear <id>` with `..` removes more than one session. Validate both against a safe pattern and refuse anything else.
4. **The hooks have no tests.** Extend `scripts/test/storage.test.sh` to the SessionStart and SessionEnd scripts (stdin JSON → output, cleanup).

Reproduce each one with a failing test first.

## Current State

Created 2026-11-11. Not started.
