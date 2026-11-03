---
title: "docs-manager: index skips git-ignored folders"
status: completed
type: bug
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Context | done | read |
| 2 | Tests | done | scripts/test/docs.test.sh G1-G5; seen failing before the fix (5 red), red again with drop_git_ignored stubbed to cat |
| 3 | Implementation | done | docs_find pipes through drop_git_ignored |
| 4 | Reflection | done | docs-manager CLAUDE.md, README updated |

## Description

A project keeps third-party material in a docs sub-folder (e.g. `docs/external/`) that `.gitignore` excludes.
`docs.sh index --write docs` still creates `docs/external/_index.md` and lists `external/` in the parent index (with
description "TODO"). The parent index is committed, so it links to a folder that is not in git: a broken link for
anyone else, and the folder's file names (which may hold confidential names) leak into the index. Every regeneration
puts the line back, so it cannot simply be reverted once.

## Acceptance criteria

- `index` and `check` skip folders and files that git ignores (e.g. `git check-ignore`), when the docs are in a git
  repo; outside git, behaviour is unchanged.
- A test with a fixture repo: an ignored sub-folder gets no `_index.md` and no line in the parent index.

## Implementation

- `docs_find` (the one walk of the docs tree, `docs-manager/scripts/lib.sh`) now ends in `drop_git_ignored <root>`: one
  `git -C <root> check-ignore -z --stdin` per walk, paths relative to the root. Because every walk goes through it,
  `index`, `links`, `check`, `external` and the diagram walks all skip ignored folders and files.
- Unchanged: outside a git repo, with no git binary, or when the root itself is ignored (the user pointed at it); a
  tracked file stays listed even if a pattern matches it (`git add -f`).
- Tests: `docs-manager/scripts/test/docs.test.sh` G1-G5. Seen failing first (G1a-d, G2 red). Defect reintroduced
  (`drop_git_ignored` returning the stream unchanged): 5 cases red. Host and bash:5 container (with `apk add git`) green.

