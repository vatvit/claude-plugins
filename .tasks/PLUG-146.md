---
title: "remote-docs: attachment questions — purpose, where cards live, a project without git"
status: proposed
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
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |

## Description

Extend the questions asked once per attachment: the folder's purpose (suggestions + other), where its cards
live (local, the default, or on Drive shared with the team), and the commit-or-not question only when the
project is a git repo. Today the publish question is asked when the remote 'cannot be told', which without
git is a question that means nothing, and `publish: local` writes a .gitignore no one reads.

## Acceptance criteria

- Without git no publish/copy-publish question is asked and nothing writes .gitignore.
- Each answer is recorded once and never asked again for that folder.
- Tests for git and no-git projects.

## Current State

Not started. Read epic PLUG-143 (Decisions, Connector facts) first.
