---
title: task — review the backlog for a tag cheaply — digest, keyword candidates, epic hints, review step
status: completed
type: feature
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | carried from PLUG-080 in the same session; body layouts surveyed |
| 20 | Requirements | done | the Scope + acceptance criteria; excerpt rule below |
| 30 | Assessment | done | read-tasks stops at frontmatter; list filters reusable |
| 40 | POC | skipped | measured on the real backlog instead |
| 50 | Domain | done | tag vs epic written down (user, mid-task) |
| 60 | Architecture | done | below |
| 70 | Tests | done | review.test.sh, 33 cases, red first; mutation-checked |
| 80 | Subtasks | skipped | one slice |
| 90 | Implementation | done | below; in the unreleased task 1.4.0 |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | tags.md, epics.md, create.md, plugin docs |

## Description

Follow-up to PLUG-080 (tags). Use case: the user asks Claude to create a new tag and review the
backlog, or a part of it, to tag the tasks that fit.

This already works with `tags.sh add` (the user's request is the OK for `--new`, the rest need
none), but reading is the cost. Measured on an 81-task set: full files ≈ 630 KB (~160k tokens),
title + first 400 chars of the description ≈ 26 KB (~7k), first 200 chars ≈ 17 KB, titles alone
≈ 6.5 KB but usually too little to judge by.

## Scope

1. **Digest.** A script (`digest.sh`, or `read-tasks.sh --digest`) printing one compact block
   per task: id, status, type, epic, current tags, title, and the start of the description
   (`## Description`; else `## Goal`, as epics have; else the first body paragraph), length
   capped. Takes the same filters as `/task list`, so a review can cover a part of the backlog.
2. **Keyword candidates.** `tags.sh candidates <tag> --match "kw1,kw2,…"`: case-insensitive
   search over the whole task text, no context cost; prints matching ids with the matching
   line, and marks the tasks that already have the tag. A shortlist, not a verdict: a task that
   never uses the words is found by the digest, not here.
3. **Epic hints.** When an epic has, or is getting, the tag, its sub-tasks (`epic:` field) are
   proposed as candidates too, flagged as "via epic".
4. **Review step** in `references/tags.md`: candidates → digest → full file only for the
   unclear ones → a proposal table (tag / unsure / skip, one-line reason each) → write after the
   user's OK → confirm with a `tags=` listing. When the backlog is large, the step says when to
   split the reading across subagents that return only proposals.

## Out of scope

- Bulk `tags.sh add --ids` (one call per task is ~0.3 s; not worth it now).
- Remembering which tasks were already reviewed for a tag.

## Acceptance criteria

- The digest of a task set is far smaller than the files (target: ≤ 1/20 of the bytes on a
  realistic fixture) and every task appears, including ones with no `## Description`.
- The digest honours the `/task list` filters (`status=`, `epic=`, `tags=`, `all`).
- `candidates` finds a task whose keyword is only in the body, not the title; reports the
  matching line; marks already-tagged tasks; never writes anything.
- Epic hints add an epic's sub-tasks, flagged, and no other tasks.
- `tags.md` describes the review step; nothing is written before the user's OK of the table.
- Bash 3.2, BSD + busybox awk; tests in the task suite, host and `bash:5`.

## Architecture

- **Excerpt in the one parser.** `read-tasks.sh --excerpt=N` keeps reading past the frontmatter and
  adds an `excerpt` field: `## Description`, else the first section that is not `## Workflow`
  (13 of 81 tasks here have Goal or Problem instead), else the text after the frontmatter. Tables,
  fences and headings dropped; cut after a whole word (macOS awk cuts bytes, so never mid-word
  `substr`), `…` when cut.
- **Digest is a `list-tasks.sh` mode** (`digest[=N]`, default 160), so it takes every list filter.
  In an epic view, membership is applied as `render_epics` does (`in_views`), so the epic's own
  task is included; `passes()` gained a field to skip for that.
- **`tags.sh candidates`**: one awk pass over the records and the files; `tagged` > `match` >
  `via epic`; the `tags:` line itself is not searched. `norm_tag` and the `TAGSOF` awk function
  are now shared by every action in the script.

## Domain: tag vs epic (from the user, 2026-10-23)

An epic is a finite batch of work, worked systematically and completed. A tag says what a task
is about and never finishes. Written to `references/tags.md` (*A tag is not an epic*), pointed to
from `epics.md`, `create.md` (step 0 of creating an epic) and the task README.

## Implementation

Measured on this repo (82 tasks, 505 KB): digest of all tasks 23.6 KB at 160 chars (1/21; at 200
it was 1/18, so the default went to 160), open tasks only 5 KB. `candidates` runs in < 0.1 s.
Suites: 215 checks green on the host, in `bash:5` and in Alpine with git.

## Current State

Completed 2026-10-23. Not committed. Ships with PLUG-080/081 in task 1.4.0 (unreleased).

