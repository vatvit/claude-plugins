---
title: crew — land waits briefly on a foreign .git/index.lock instead of failing
status: completed
type: improvement
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | task read |
| 20 | Requirements | done | scope + acceptance as written |
| 30 | Assessment | skipped | small |
| 40 | POC | skipped | none needed |
| 60 | Architecture | skipped | one helper |
| 70 | Tests | done | red first |
| 90 | Implementation | done | host + container green |
| 100 | Tech Debt | skipped | none |
| 110 | Reflection | skipped | docs text proposed to the doc-owning session |

## Description

With several sessions on one tree, `crew land` regularly failed because another session's git command held
`.git/index.lock` for a moment. The coordinator then looped by hand until the lock cleared. Deleting the lock is
never right; waiting is.

## Scope

- `land` (and `apply`) retry for a bounded time (config, default ~60 s) while `.git/index.lock` exists, then fail
  with the holder's pid if it can be found. Never remove the lock.

## Acceptance

- A held lock released after 3 s: land succeeds. A lock never released: land fails after the bound, naming the lock,
  and the lock is still there.

## Implementation

- `crew/scripts/land.sh`: `wait_index_lock` (poll every 0.2 s until `.git/index.lock` is gone, bounded by the new config key `lockWaitSec`, default 60 s; on timeout it fails naming the lock and, via `lsof`/`fuser` when present, the holder pid; it never removes the lock). `lock_holder` is the pid lookup. `land` calls it before `git add`/`git commit`; `copy apply` calls it (through `load_area land`) before it writes the tree.
- `lockWaitSec` added to `CREW_KEYS` and `cfg_default` in `crew/scripts/lib.sh` (two one-line edits) and to the numeric keys in `crew/scripts/config.sh`.
- Tests: `land.test.sh` (lock released after 3 s: lands; never released with a 2 s bound: exit 1, lock named, lock still there, nothing committed; `config` lists the key) and `copy.test.sh` (apply: the same two cases).
- Red first: both new blocks failed before the fix (land: 7 failures, copy: 3). After the fix the wait calls were removed again: land 6 and copy 1 checks went red; restored, all green.
- Host and container (`crew-test`) full crew suite green.
