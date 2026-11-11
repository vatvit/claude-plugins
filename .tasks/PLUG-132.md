---
title: "session-storage — hardening: jq dependency, stat order, unchecked session id and key used as paths, hooks untested"
status: completed
type: bugfix
priority: medium
tags: ["session-storage-plugin"]
created: 2026-11-11 18:59
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | see ## Context |
| 30 | Assessment | done | small, one plugin; no other session holds its files |
| 60 | Architecture | done | a plugin-own `scripts/lib.sh` (storage root, ss_safe_name, ss_json_session_id, ss_mtime) sourced by all three scripts |
| 70 | Tests | done | storage.test.sh 9 → 34 cases, 14 red first; stat order and hook id check proven red |
| 90 | Implementation | done | 34/34 on host, bash:5 container, standalone copy |
| 100 | Tech Debt | done | none new |
| 110 | Reflection | done | plugin CLAUDE.md, README, SKILL.md (key naming); no version bump |

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

## Context

- Plugin files: `scripts/storage.sh` (CLI), `scripts/capture-session.sh` (SessionStart), `scripts/cleanup-session.sh` (SessionEnd), `hooks/hooks.json` (5 s timeout each). There is no `lib.sh` yet. Its tests are in `scripts/test/storage.test.sh`: 9 checks, its own `check`/`has` helpers, run on host and `bash:5`. PLUG-122 (completed, committed) added the plain "cannot write" refusal and the no-HOME check.
- The defects, confirmed by reading:
  1. Both hooks run `jq -r '.session_id // empty'`. Without jq, `session_id` is empty and the hook exits 0 silently: no context injected and no cleanup. `plugin CLAUDE.md` still lists jq as a required dependency.
  2. `storage.sh list` tries `stat -f %m` first. On busybox that prints filesystem status to stdout, so `$(...)` captures junk (root CLAUDE.md *File mtime*).
  3. `session_id` and `key` are spliced into paths unchecked in `set`, `get`, `clear` and both hooks. The worst case is `cleanup-session.sh` with `"session_id":".."`: it runs `rm -rf $STORAGE_DIR/..`, which is the whole tmp dir. `clear ..` does the same, and `set s ../../x v` writes outside the storage dir.
  4. The hooks have no tests.
- Callers: the task plugin's `session-active.sh` uses key `active-tasks`, and Claude Code session ids are UUIDs. Both fit a safe pattern such as `^[A-Za-z0-9][A-Za-z0-9._-]*$`. A leading dot is refused, which also excludes `.`, `..` and the hidden files `list` skips.
- Prior art for jq-free parsing: `task-roadmap/scripts/lib.sh` `json_str` (grep -o + sed). Per plugin independence, session-storage gets its own `scripts/lib.sh` and never sources another plugin's file.
- Rules that apply: hooks always `exit 0` and report on stderr (root CLAUDE.md); bash 3.2; BSD + GNU + busybox; no `| grep -q` under pipefail in tests.

## Implementation (2026-11-11)

- `scripts/lib.sh` (new, sourced by `storage.sh` and both hooks) holds:
  - `SS_STORAGE_DIR`, so the storage root is defined once instead of three times.
  - `ss_safe_name`: `[A-Za-z0-9._-]`, no leading dot, at most 128 characters.
  - `ss_json_session_id`: grep + sed over the JSON with newlines folded, so no jq.
  - `ss_mtime`: `stat -c %Y`, then `stat -f %m`.
- `storage.sh`: `set`, `get`, `clear` and `list <id>` refuse a bad session id or key with exit 1 and a message saying which characters are allowed. `list` uses `ss_mtime`.
- Hooks: no jq. A bad id gives exit 0 and a stderr note, and touches nothing. `capture-session.sh` names `storage.sh` by its own dir and reports an unwritable storage dir on stderr. `cleanup-session.sh` uses `${STORAGE_DIR:?}`.
- Test lessons:
  - A hostile id of `..` proves nothing, because `rm` itself refuses to remove `..`. `../claude-session-storage` is the id that removed every session.
  - The fake `stat` has to act like GNU stat (`-c` works, `-f` prints junk) to go red on a BSD host as well.
- Not bumped: session-storage stays at 1.0.0 (no release requested).

## Current State

Completed 2026-11-11. Not committed. storage.test.sh 34/34 on host, bash:5 and a standalone copy.
