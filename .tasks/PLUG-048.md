---
title: crew — copy rebase reads an empty path when the copy has no changes
status: completed
type: bug
epic: crew-feedback
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | copy_rebase in crew/scripts/copy.sh |
| 20 | Requirements | done | acceptance criteria below |
| 30 | Assessment | done | copy.sh + copy.test.sh + copy-apply.md, none hot |
| 40 | POC | skipped | not needed |
| 50 | Domain | skipped | no new concepts |
| 60 | Architecture | done | see Architecture |
| 70 | Tests | done | copy.test.sh, red first |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | applied to the tree, awaiting land |
| 100 | Tech Debt | done | none added |
| 110 | Reflection | done | see Reflection |

## Description

Found while running the crew on itself (PLUG-041). `copy rebase` on a copy with **no changes**
reads one empty path: `done <<EOF $(copy_changes) EOF` yields one blank line. Then it runs
`cp <copy>/` (a directory) and `git cat-file <sha>:` (a bad file), and reports "1 changed files
carried over". It is harmless today, because the checkout still moves the copy. `apply` already
skips blank paths; `copy_rebase` does not.

Second gap, found while rebasing PLUG-043's copy past PLUG-044, which changed the same lines of
`session-start.sh`. After a worker resolves a conflict inside the copy, `copy rebase` still compares
the old base, the new base and the copy, and refuses again, so "resolve in the copy" is not
actionable. Add `copy rebase <dir> --ours <path>…`: take the copy's file as already resolved against
the new base.

## Acceptance criteria

- [x] `copy rebase` on an unchanged copy prints no errors and reports 0 files carried over.
- [x] Regression check in `copy.test.sh`, red on 1.1.x.
- [x] `copy rebase --ours <path>` accepts the copy's version of a conflicting path. The refusal
      message names the flag, and without it the rebase still refuses.
- [x] Suites pass on host + docker.

## Context

`copy_rebase` (`crew/scripts/copy.sh`) reads `copy_changes` through a here-doc. When there are no
changes, the here-doc still yields one blank line, and `copy_apply` already skipped it.
`copy_rebase` refused on any `resolve3` conflict, so a conflict resolved inside the copy refused
again: old base, new base and copy still clash.

## Architecture

- `copy_rebase` skips a blank path, as `copy_apply` does. "N changed files carried over" now counts
  real paths only.
- `copy rebase <dir> [--ours <path...>]`. `copy_main` parses the flag and passes the repo-relative
  paths to `copy_rebase`.
  - Only a **conflict** on a named path becomes the decision `ours`: after the checkout of the new
    base, the copy's file is restored, or deleted if the copy deleted it. Every other file keeps
    its usual decision, and a conflict on a path that is not named still refuses the whole rebase.
  - A named path that had no conflict is reported ("no conflict there, rebased as usual").
- The refusal now says how to see the tree's version (`git -C <dir> show <sha>:<path>`) and
  prints `copy rebase <dir> --ours <conflicting paths>`, quoted with `%q`.

## Tests

`crew/scripts/test/copy.test.sh`, 45 checks, green on the host and in `crew-test`. Every suite is
green on both. Written first: 6 red on HEAD. One of them was the blank path itself:
`cp: …/copy/ is a directory`.

**Shown failing:**
- dropping the blank-path skip fails "…no errors" and "…0 files carried over";
- letting `--ours` cover every conflict, not only the named paths, fails 4 checks, starting with
  "--ours covers only the paths it names".

## Implementation

`crew/scripts/copy.sh` (help line, `copy_rebase`, `copy_main`), `crew/scripts/test/copy.test.sh`,
`crew/skills/crew/references/copy-apply.md`. No version bump (the coordinator lands it as a
patch). The README command row still reads `copy new|status|rebase <dir>`. README is a hot spot,
so adding `--ours` there is left to the coordinator.

## Tech Debt

None added.

## Reflection

The resolve-then-`--ours` flow is in `references/copy-apply.md`, where a worker hitting the
refusal reads next.
