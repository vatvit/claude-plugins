---
title: "docs.sh links: check #anchor targets exist"
status: completed
type: feature
priority: medium
tags: [quality]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | read |
| 20 | Requirements | done | from the task description |
| 30 | Assessment | skipped | small |
| 40 | POC | skipped | small |
| 50 | Domain | skipped | n/a |
| 60 | Architecture | done | doc_link_records + md_anchors in lib.sh, anchor_check in docs.sh |
| 70 | Tests | done | docs.test.sh A1-A8, each seen failing before the fix |
| 80 | Subtasks | skipped | n/a |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | see Implementation: limits |
| 110 | Reflection | done | docs-manager CLAUDE.md, README, SKILL.md updated |

## Description

docs-manager's `docs.sh check` verifies that a cross-doc link's target file exists, but not the `#anchor` part.
A link such as `other.md#some-section` (or `#some-section` within the same file) still passes after that heading is
renamed or deleted, so the link silently leads nowhere. Seen in practice: a lost `##` heading left links from two
other places pointing at nothing, and the check stayed OK.

Make the links check also resolve anchors: for a link with `#fragment`, the target doc (or the same doc) must have
a heading whose generated slug equals the fragment (GitHub-style slugs: lower-case, spaces to `-`, punctuation
dropped; duplicate headings get `-1`, `-2` …). Explicit HTML anchors (`<a id="…">`) count too.

## Acceptance criteria

- A fixture doc set: a link to an existing heading passes; a link to a missing heading fails with the file, the
  line and the fragment; a same-file `#fragment` link is checked too; duplicate-heading suffixes resolve.
- Each test seen failing first.
- Links to non-markdown targets and external URLs are untouched.

## Current State

Proposed. Not started.

## Implementation

- `doc_link_records` (lib.sh) is the one link stream, now with line number and `#fragment` (same-file `#frag` links
  included); `doc_links` is its path-only view, so `external related` and the path check are unchanged.
  `md_link_dests <file> n` can prefix line numbers.
- `md_anchors <file>`: `s:<slug>` per ATX heading (lower-case, ASCII punctuation and common Unicode punctuation dropped,
  `-` and `_` kept, each space a `-`, links reduced to their text, `-1`/`-2` for repeats) and `i:<id>` per `id=` or `name=` on any
  tag. Code fences ignored. `anchor_check` (docs.sh) joins them with the links; `BROKEN ANCHOR: file:line -> link#frag`.
  Only links to existing `.md` files are checked (a missing file is already BROKEN LINK); `#top` is skipped.
- Awk portability: both programs run under `LC_ALL=C` with a shared `lc()` (`AWK_FOLD`), because busybox `tolower` does not
  lower-case `Ü` while BSD awk and gawk do; found by the bash:5 run of case A4. No `{n,m}` regex intervals (old BSD awk).
- Limits: no setext headings; letter case beyond Latin-1, Greek, Cyrillic not folded; non-ASCII punctuation beyond the list in
  `md_anchors` not dropped.
- Tests: `docs-manager/scripts/test/docs.test.sh` A1-A8 (existing/missing heading, line + fragment, same-file, duplicate
  suffixes, punctuation/backticks/non-ASCII/em dash/%-encoded fragment, explicit anchors, fence, non-md/URL/#top untouched).
  Seen failing before the fix (9 red). Reintroduced: anchor pass removed -> 8 red; duplicate suffix removed -> A3a red.
- The new check found a real dangling anchor in a fixture: `onboard.test.sh` linked `setup.md#ports` with no such heading;
  the fixture got a `## Ports` heading. This repo's own docs (`docs-manager` tree, `.tasks`) have no broken anchors.


### Follow-up: fenced code blocks

- `md_link_dests` (the one link parser) now skips lines inside a ``` or ~~~ fence, so example links there give neither
  BROKEN LINK nor BROKEN ANCHOR. Test A9 in `docs.test.sh`: seen red first (5 reports instead of 2), red again with the
  skip removed, green after. All four docs-manager suites green on the host and in bash:5 with git.
- `docs.sh links .` on this repo: 9 BROKEN LINK lines before, 6 now. The 6 left are examples in inline code spans or
  prose (`docs-manager/CLAUDE.md` x2, `how-to-external-docs.md` x3, `how-to-onboard.md` x1), not fences.
- `survey`'s link rewriting also reads `md_link_dests`, so a link in a fence is no longer listed there; its replacement is
  textual on the listed destinations, so behaviour only differs when a fenced example is the sole user of a destination.
