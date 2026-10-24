---
title: awk compares IDs and names as numbers when they look numeric (crew, kickoff, docs-manager)
status: completed
type: bug
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | PLUG-015 |
| 20 | Requirements | skipped | ACs in the task |
| 30 | Assessment | done | every site classified, see Results |
| 40 | POC | skipped | |
| 50 | Domain | skipped | |
| 60 | Architecture | skipped | |
| 70 | Tests | done | crew holds, kickoff 1k/1l, red first |
| 80 | Subtasks | skipped | |
| 90 | Implementation | done | crew 2.3.2, kickoff 0.8.1 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | root CLAUDE.md awk note widened |

## Description

PLUG-015 found that awk `$1 == id` compares numerically when both sides look like numbers:
busybox reads hex `75e763` and `7e1794` as infinity, so they are equal (delay fixed with
`($1 "") == id`; the trap is in the root CLAUDE.md awk list). The same `$N == var` pattern
appears in other plugins, e.g. crew `snapshot.sh`, `slot.sh`, `msg.d/slots.sh`, `msg.d/holds.sh`,
`watch.sh`, `lib.sh`; kickoff `ports.sh`, `inspect.sh`; docs-manager `survey.sh`, `external.sh`.
Most compare names, paths or integers, where it is at worst an edge case (a session name `1e5`
equal to `100000`), but each needs a look.

## Acceptance criteria

1. Every `$N == var` awk comparison of an id, name or path in crew, kickoff and docs-manager is
   either a forced string compare or noted as numeric on purpose (e.g. integer slot ids).
2. Where a real collision is possible, a test shows it (red in the container before the fix).
3. Each plugin's suite is green on the host and in the container.

## Results (2026-10-24)

A real collision needs no exotic ID: every awk (macOS and busybox) reads `010` as `10`.
- **crew** (fixed, forced string compares): holds by path (`holds.sh` hold_field and the rewrite,
  `msg.d/holds.sh` release), claims by path (`lib.sh` claimants), snapshots by path and blob hash
  (`snapshot.sh`), session names (`watch.sh`, `msg.d/holds.sh` hand-off, `slot.sh` "(you)" and the
  slot of a name). Test: s1 holds `010`, then s2's hold on `10` was refused as held by s1 (red on the
  host), now granted (holds.test.sh).
- **kickoff** (fixed): `ports.sh` names (port_of, set, release) and `inspect.sh` (an absolute compose
  path, never number-like, changed for one rule). Test 1k/1l: `allocate 010` returned `10`'s port and
  `release 010` dropped `10` (red), now separate.
- **Numeric on purpose, unchanged:** crew snapshot and slot ids (integer sequences, `01` finding `1`
  is fine), kickoff `$2 == p` (a port).
- **Never number-like, unchanged:** kickoff question ids (`A0`…, letter first); docs-manager
  `survey.sh` moves (markdown paths, `.md`), `external.sh` (paths under `docs/external/`, and cards
  ending `.md`), `lib.sh`/`survey.sh` block markers (`$0 == start`, literal comments); task scripts
  (`$1` is a task id, `PLUG-…`).
- **Out of scope, noted:** task's `resolve-epic.sh` compares `ename == target`. A digits-only epic
  reference is read as a task id before any name lookup, so only names like `1e5` vs `100000` could
  collide there: left as is.
- **Verified:** crew host and container suites green (twice, run together); kickoff 53/53 on the host and in the container. One unrelated crew flake under load, filed as PLUG-086.
