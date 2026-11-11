---
title: "task: git id source: bound the network time and the local lock wait"
status: completed
type: refactor
priority: low
epic: task-id-sync
tags: ["task-plugin", "git-sync-feature"]
created: 2026-11-11 19:05
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | id-git.sh network calls, allocate-id.sh lock loop |
| 20 | Requirements | done | acceptance criteria below |
| 30 | Assessment | done | macOS has no `timeout`: a bash watchdog, portable to busybox |
| 60 | Architecture | done | one wrapper `idgit_net`; lock heartbeat via IDGIT_LOCK; long wait when idSource is git |
| 70 | Tests | done | net-timeout.test.sh 11 cases, all 7 mechanism checks red before the change |
| 90 | Implementation | done | all suites green: host, task-test container, standalone copy |
| 110 | Reflection | done | id-sources.md (deadline paragraph, troubleshooting row), task/CLAUDE.md Don't-regress + test list |

## Description

Shortcut taken in PLUG-125. In `idSource: git` mode, `allocate-id.sh` holds the local id lock (`{tasksDir}/.id-alloc.lock`) during the fetch and push. There is no timeout:

- A remote that hangs (a stalled ssh, a slow VPN) blocks allocation indefinitely. `GIT_TERMINAL_PROMPT=0` only stops password prompts.
- Another session on the same machine waits at most 10 s for the lock (100 × 0.1 s) and then fails with "could not acquire id lock". After 120 s it treats the held lock as stale and breaks it. The remote compare-and-swap still prevents duplicate ids, but both outcomes are confusing.

Options: a bounded time per git call (`http.lowSpeedLimit/Time`, `ssh -o ConnectTimeout`, without overriding the user's own `core.sshCommand`); falling back to the local path (pending sync, PLUG-128) on timeout; a longer lock wait in git mode.

## Acceptance criteria (draft)

- A remote that never answers makes allocation fall back or fail within a bounded time, documented in `references/id-sources.md`.
- A second session waiting for the lock during a slow but healthy push does not fail.

## Implementation (2026-11-11)

- `idgit_net <repo> <git args>` in id-git.sh runs every git call that reaches the remote (ls-remote in probe and fetch, fetch, push, the first-use fetch). It enforces a deadline of `TASK_ID_NET_TIMEOUT` (default 20 s, 1..100, any other value ignored, never executed) with a background job and a 0.1 s poll. On expiry it kills git and returns 124. Output goes through temp files, because an ssh that outlives the killed git would otherwise keep a `$( )` pipe open: the case the test hit with 61 s before the change.
- A probe timeout counts as unreachable, so allocation falls back to pending (PLUG-128). A push timeout fails with "did not finish within Ns; its numbers may be spent (a gap, never a duplicate)" and creates no file.
- Lock: when idSource is git, a waiter waits (STALE_AFTER + 5) s instead of 10 s. The holder touches the lock before each network call (IDGIT_LOCK), so a healthy holder never looks stale. The 100 s cap on the timeout keeps one call under STALE_AFTER (120 s).
- Not done: ssh `ConnectTimeout` or `http.lowSpeed*` options. The watchdog covers every transport without overriding the user's `core.sshCommand`.

## Current State

Completed 2026-11-11, in task 1.6.0, not committed. net-timeout 11/11, and every suite is green on host, container and standalone.
