---
title: "remote-docs: folder purpose and scope, declared per folder and inherited"
status: completed
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
| 10 | Context | done | epic PLUG-143 Context + remote.sh read (source_of, diff) |
| 20 | Requirements | done | ## Requirements |
| 30 | Assessment | done | ready: PLUG-144 landed (e4f7c7b), suite green |
| 40 | POC | skipped | no unknown: offline script logic only |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | ## Architecture |
| 70 | Tests | done | PP1–PP8 in remote.test.sh, seen red (18 failing) before the code |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | remote-docs CLAUDE.md (Folder purpose invariants), how-to, README, SKILL, root vocabulary |

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

## Requirements

The epic's Decisions (PLUG-143), plus the answer to the open question (2026-11-16, plan approved by the
user): **purpose goes in `.source.md`**, resolved per key from the nearest file that sets it; on Drive it
travels with the cards (PLUG-148). Keys: `purpose`, `writes`, `truth`, `scope`, `scopes`, `cards`.
Fallback: `writes: never`, `truth: no`, `scope: project`, `cards: files`.

## Architecture

- `src_key`/`src_val` replace `source_of` everywhere (publish, processed, the new keys); a suggested
  purpose implies `writes`/`truth`/`cards` at its own level (`purpose_default`).
- `purpose <path> [root]` and `purposes [root]` print the resolved record.
- `check` adds `BAD SETTING`, `PURPOSE INCOMPLETE`, `SCOPE UNKNOWN` (fail) and `PURPOSE?` (note).
- `cards: pointer`: `diff` compares the newest in-scope time with the pointer card (`diff_pointer`).

## Implementation (2026-11-16)

Done as designed in `remote-docs/scripts/remote.sh`. The how-to gained *Folder purpose* (settings
table, how to act on each, custom purpose, scope care, fallback). Suite 117 green on host, `bash:5`,
`bash:5` + git, no HOME.

## Current State

Completed 2026-11-16. Next in the epic: PLUG-146.
