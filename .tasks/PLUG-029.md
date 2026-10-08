---
title: crew — work in a copy, land with merge-or-refuse apply
status: completed
type: feature
epic: crew
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | same session; PLUG-026 Architecture applies; user rule: no worktrees |
| 20 | Requirements | skipped | ACs specific enough |
| 30 | Assessment | done | probed: `clone --shared` sees new commits via alternates; merge-file rc 255 on binary |
| 40 | POC | done | the probe above (clone alternates, merge-file on binary) |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | `crew/scripts/test/copy.test.sh` (29 checks) |
| 80 | Subtasks | skipped | small enough |
| 90 | Implementation | done | 158/158 host + docker |
| 100 | Tech Debt | done | none filed |
| 110 | Reflection | done | references/copy-apply.md, SKILL/README rows; 0.5.0 |

## Description

Unfinished or failing work stays out of the shared tree (playbook §3, §9.4). A session works
in a copy and lands it with a merge-or-refuse apply.

- `copy.sh new <dir> [--at <commit>]` creates a copy of the tree at a named commit (a
  scratchpad or container path) and records its base. `copy.sh rebase <dir>` moves the copy
  onto the commit the shared tree is on now, with the same take / merge / refuse rules.
- `apply.sh <dir> [paths…]`, for each file changed in the copy:
  - **take** when the tree still matches the base;
  - **3-way merge** (`git merge-file`) when a peer changed it;
  - **refuse** on a conflict, naming the file.

  Nothing lands unless every file is clean. The summary line is "apply: N taken, M merged,
  K refused".
- Optional `landCheck` command in `.crew.json` (e.g. a formatter check), run on the landed
  file list. If it fails, the apply is refused and the tree is left untouched.
- `references/copy-apply.md`.

## Acceptance criteria

- [ ] An untouched base gives *taken*. A peer edit in another hunk gives *merged*, with both
      edits present.
- [ ] A conflicting peer edit gives *refused*, names the file, and leaves the tree
      byte-identical.
- [ ] A copy based on an older commit and rebased onto HEAD applies cleanly.
- [ ] A failing `landCheck` refuses the whole apply.
- [ ] Added and deleted files are handled. Paths with spaces work.
- [ ] The suite passes in docker and from a standalone copy.

## Architecture

- `crew/scripts/copy.sh` (`copy new|status|rebase`, and `apply` routed by `crew.sh`).
- A copy is `git clone --shared --no-checkout` + detached checkout at the base. It is not a
  worktree and not a branch: the user forbids both. Through alternates it sees new commits in the
  shared repo, so rebase needs no fetch. The base is recorded in `<copy>/.git/crew-copy`
  (`base= root= made=`).
- ONE decision function, `resolve3 <target> <base> <incoming> <out>` → same | take | delete |
  keep | merged | conflict. Apply calls it as (tree, base, copy) and rebase as (new HEAD, old
  base, copy). Absent files, binary files (NUL) and delete-vs-change all count as conflicts.
- Apply is two-phase under the `apply` lock: decide every file first and refuse everything on any
  conflict. Then write, re-checking that each target has not changed since the decision. Then run
  `landCheck` on the landed paths. Any failure restores the originals kept from the decision
  phase, so the tree ends up byte-identical.
- Apply respects holds (held by another session, or an unheld hot spot → refused) because its
  writes bypass the pre-edit hook. It snapshots overwritten files via `snapshot_save` when the
  snapshot area is present, and claims the landed paths for the caller.

## Implementation

`copy.sh`, `crew.sh` (apply route), `copy.test.sh` 29/29; full run 158/158 on host and in `crew-test`.

## Reflection

`references/copy-apply.md`, SKILL pointer row, README row; plugin 0.5.0. No repo-level lessons.

## Current State

Completed. Build green.
