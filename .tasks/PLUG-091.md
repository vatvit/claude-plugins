---
title: crew — status collapses an untracked directory to one line, as git status does
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

`crew status` expands untracked directories file by file. A project with a scratch directory of review renders
printed over 9,000 dirty paths, so the screen meant to show "who owns what" was unreadable and sessions fell back to
`crew who <path>`. `git status` shows such a directory as one line.

## Scope

- Untracked directories show as one line with a file count and its owner (or "unclaimed"), unless a member holds a
  path inside it, which is then listed.
- An option to expand (`status --all`).

## Acceptance

- A fixture with 1,000 untracked files in one dir prints one line for it; a held path inside it still shows.

## Implementation

- `crew/scripts/status.sh`: `collapse_untracked_dirs` folds each untracked directory (as `git status -unormal` shows it) into one `<dir>/ (N files)` line placed in the group of its files' claimants (union; unclaimed when none). A path a member holds stays listed on its own. A directory with a single file lists that file (more informative, equally short). `dirty (N)` still counts every file. `status --all` expands everything; any other argument is refused.
- Tests: new `crew/scripts/test/status.test.sh` (1,000 untracked files in one directory: one line, short screen, dirty count, owner group, held path listed, `--all`, unknown option).
- Red first: 6 of 14 checks failed before the fix; with the fix switched off again (always expand) 5 went red; restored, green.
- Side effect: `core.test.sh` "shared path flagged" relied on a single untracked file in a new directory being listed; the single-file rule keeps it unchanged.
- Host and container (`crew-test`) full crew suite green.
