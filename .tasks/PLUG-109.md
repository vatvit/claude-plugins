---
title: "crew — copy remove refuses a copy whose work landed and was changed again on the tree since"
status: completed
type: improvement
priority: low
tags: ["crew-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 70 | Tests | done | red first, in a fixture repo: a copy file whose content is a landed commit's blob, later changed on the tree, is removable; a file in no commit still refuses |
| 90 | Implementation | done | `copy_verdicts` in copy.sh; status shows the verdicts too |
| 100 | Tech Debt | skipped | no shortcut taken |
| 110 | Reflection | done | crew/CLAUDE.md copy rule, references/copy-apply.md |

## Problem

`crew copy remove <name>` (crew 2.5.0, `scripts/copy.sh` `copy_unlanded`, line ~80) refuses while any changed file in
the copy differs from the shared tree's file **as it is now**. `--force` does not override it. After a copy's work is
applied and landed, later commits on the tree usually change the same files again, so the copy's version no longer
equals the tree's, and the copy can never be removed. Its work is all in history, but crew reports "has work the tree
does not".

Seen: one worker had 19 old copies (~6.2 GB), all landed. A one-off audit found each changed file's content as the
blob of a commit on the branch since the copy's base, and crew refused all 19 of them. The only ways out are dropping
the files in each copy by hand or removing the worktree outside crew, and the rules forbid a session from doing either.

## Scope

- In `copy_unlanded`, a file is landed when its content equals the tree's file, **or** equals the blob of some commit
  on the branch between the copy's base (its HEAD) and the tree's HEAD (`git rev-list <base>..HEAD -- <file>`, compare
  `git rev-parse <sha>:<file>` with `git hash-object`). A file under the copy's untracked scratch (e.g. `tmp/`) the
  tree also leaves untracked is not work either (or say why it is).
- `copy remove` prints, per file, the commit that holds it, so the removal is auditable.
- A file whose content is in no commit still refuses, as now.
- Optional: `copy status <name>` shows the same per-file verdict (landed in <sha> / on the tree / not landed).

## Acceptance

- Fixture repo: copy edits f → applied and committed as C1 → the tree edits f again as C2 → `copy remove` succeeds and
  names C1.
- The same, with an extra uncommitted edit in the copy → refused, naming f.

## Tests

`copy.test.sh` › *remove: work that landed and was changed again since*, in a fixture repo: the copy edits `f.txt` and
deletes `gone.txt`, both applied and committed as C1, then the tree changes both again as C2.
- `copy status` names C1 for each file (the deletion too).
- A further edit to `f.txt` in the copy is refused, naming `f.txt` and not `gone.txt`.
- An untracked `notes.tmp` is refused, and the message names `info/exclude`.
- With both gone, `copy remove` succeeds, prints `f.txt — landed in <C1>` and `gone.txt — landed in <C1>`, and the folder is gone.
Red before the fix: remove refused `f.txt` and `gone.txt`.

## Implementation

- `copy_verdicts <dir>`: one `<path>\t<where>` per changed path, where `<where>` is one of three values. `tree` means
  it equals the tree's file. A short sha is the oldest commit in `<base>..HEAD` touching the path whose blob (via
  `hash-object --path`) equals the copy's version, or that lacks the path for a deletion. Empty means not landed.
  `copy_unlanded` (also used by `crew end`) is that filtered by `verdict_lost`, so `remove`, `status` and `end`
  share one rule.
- `copy remove` prints each file's verdict before removing. A refusal also says how to keep scratch out:
  `.git/info/exclude`.
- `copy status` lists the verdict per file (the optional scope item).
- Untracked scratch: still refused, by decision (the scope allowed "or say why it is"). No commit proves an
  untracked file is kept anywhere. `copy_changes` already skips ignored files, so `info/exclude` (shared by every
  worktree, never committed) is the way to declare scratch.
- Full crew suite green on the host (bash 3.2) and in `crew-test` (bash 5, busybox).
- Unreleased: crew stays at 2.5.0 until the next crew release.

## Current State

Completed. The 19 old copies from the report can now be removed with `crew copy remove <name>`, once crew is
released and updated.
