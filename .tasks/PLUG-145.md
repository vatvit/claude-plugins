---
title: "remote-docs: folder purpose and scope, declared per folder and inherited"
status: proposed
type: feature
priority: medium
epic: remote-docs
deps: [PLUG-144]
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

A folder declares its purpose in a file inside it; a folder without one inherits from its parent. Free
text purpose from a suggested list plus *other*; `writes: never | propose | free` and `truth: yes | no`
for scripts; scope in the order `user > project > team > company`, extendable by the user. Fallback with
nothing declared: `writes: never`, `truth: no`, and Claude asks once. Details: epic PLUG-143, *Decisions*.

Open for Requirements: the purpose file. `.source.md` already is per-folder data and already inherits
upward (`source_of`); does purpose go there, and must it also exist on Drive so every teammate's Claude
sees it?

## Acceptance criteria

- A script resolves the purpose, `writes`, `truth` and scope of any folder under the docs root,
  inheritance and fallback included.
- Collaboration-type folders default to one pointer, not per-file cards.
- The how-to tells Claude how to act on each setting, and how to treat a custom purpose.

## Current State

Not started. Read epic PLUG-143 (Decisions, Connector facts) first.
