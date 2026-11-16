---
title: "remote-docs: attachment questions — purpose, where cards live, a project without git"
status: completed
type: feature
priority: medium
epic: remote-docs
deps: [PLUG-145]
tags: ["remote-docs-plugin"]
created: 2026-11-16 14:55
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | how-to attaching step 3, folder attach, local copy, artifacts; the PLUG-145 resolver |
| 20 | Requirements | done | ## Requirements |
| 30 | Assessment | done | ready: PLUG-145 landed (7d26f15) |
| 40 | POC | skipped | no unknown |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | AQ1a–f, AQ2a–c (git, skipped without it), seen red (9 failing) first |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | remote-docs CLAUDE.md (Attachment questions), how-to step 3, SKILL triggers |

## Description

Extend the questions asked once per attachment: the folder's purpose (suggestions + other), where its cards
live (local, the default, or on Drive shared with the team), and the commit-or-not question only when the
project is a git repo. Today the publish question is asked when the remote 'cannot be told', which without
git is a question that means nothing, and `publish: local` writes a .gitignore no one reads.

## Acceptance criteria

- Without git no publish/copy-publish question is asked and nothing writes .gitignore.
- Each answer is recorded once and never asked again for that folder.
- Tests for git and no-git projects.

## Requirements

Acceptance criteria above, with the approved plan (2026-11-16): the questions come from a script, so
"asked once" and "not without git" are testable rather than prose.

## Architecture

`remote.sh questions <dir> [root]` prints, in asking order: `purpose`; `writes`/`truth` for a custom
purpose whose file lacks them; `cards-at` (`local` | `drive`, a new `.source.md` key validated by
`check`); and, only in a git work tree, `publish` and (with `processed: local`) `copy-publish`. An answer
anywhere up the `.source.md` chain counts.

## Implementation (2026-11-16)

As designed. The how-to's attaching step 3 now runs `questions` and asks only what it prints; folder
attach, local copies and artifacts point to it. Suite 126 green on host and `bash:5` + git; 121 + 3
skipped in plain `bash:5` and without HOME.

## Current State

Completed 2026-11-16. Next in the epic: PLUG-147.
