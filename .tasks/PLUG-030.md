---
title: crew — snapshot before every write, log/show/restore
status: completed
type: feature
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | same session; pre-edit hook already calls `snapshot_save` via load_area; apply calls it too |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | measured hook at ~95 ms/edit → config forks were the cost |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `crew/scripts/test/snapshots.test.sh` (20 checks) |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 178/178 host + docker; hook ~51 ms/edit |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | references/snapshots.md, SKILL/README rows, crew CLAUDE.md config-cache rule; 0.6.0 |

## Description

A snapshot before every write, so an overwritten edit can always be recovered (playbook §3).

- A PreToolUse hook on Write/Edit/MultiEdit/NotebookEdit copies the target's current content
  (when the file exists and differs from the last snapshot) to `.git/crew/snapshots/`,
  recording session, time and path. The hook never blocks and stays fast.
- `snapshot.sh log <path>`, `show <id>`, `restore <id>` (restore is itself snapshotted
  first), `prune` (by `snapshotKeep` count/age in `.crew.json`).
- Size guard: files above a set limit and binary files are skipped with a single stderr note.
- `references/snapshots.md`.

## Acceptance criteria

- [ ] s1 edits a file and s2 overwrites it. `log` shows both versions and `restore` brings
      s1's version back.
- [ ] An unchanged file is not snapshotted twice in a row.
- [ ] `prune` respects the retention setting.
- [ ] The hook adds under ~50 ms on a normal source file and never fails the tool call.
- [ ] The suite passes in docker and from a standalone copy.

## Architecture

- `crew/scripts/snapshot.sh`, dual-use. Each distinct version's content is stored once at
  `snapshots/blobs/<git blob hash>`. The log `snapshots/log` is TSV (id, time, session, path,
  hash, bytes) with ids from `snapshots/seq`. `_snap_add` runs under the `snapshots` lock: it
  dedupes against the path's newest entry and trims that path to `snapshotKeep` in the same
  rewrite. `prune` re-applies the limit and deletes unreferenced blobs.
- Skips binary files (a NUL is present) and files over `snapshotMaxKB`, with one stderr note
  each, and never blocks.
- `restore` snapshots the current content first, so a restore can be undone. It is refused on
  a file another session holds, and it claims the path for the caller.
- **Performance fix (in lib, applies to every hook):** config is parsed once per process into
  `CREW_CFG`, and `cfg` resolves layers with no fork; `crew_try_init` uses one
  `git rev-parse --path-format=absolute --show-toplevel --git-common-dir`. Pre-edit hook: ~95 → ~51 ms
  per edit on the host, crew active, with holds, a snapshot and a claim.

## Implementation

`snapshot.sh`, `lib.sh` (cfg_parse/cfg_load/cfg_resolve replace json_val), `config.sh`;
`snapshots.test.sh` 20/20; full run 178/178 on host and in `crew-test`.

## Reflection

`references/snapshots.md`, SKILL/README rows, crew `CLAUDE.md` design rule "config is parsed once
per process" (and the git ≥ 2.31 requirement it brings). Plugin 0.6.0.

## Current State

Completed. Build green.
