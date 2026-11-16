---
title: "remote-docs: new plugin, remote cards moved out of docs-manager unchanged"
status: completed
type: refactor
priority: medium
epic: remote-docs
deps: []
tags: ["remote-docs-plugin", "docs-manager-plugin"]
created: 2026-11-16 14:55
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | epic PLUG-143 ## Context covers it; code read: external.sh, docs.sh, lib.sh, external.test.sh |
| 20 | Requirements | done | ## Requirements |
| 30 | Assessment | done | ready: docs-manager committed (fd367c5), suites green host + container |
| 40 | POC | skipped | a move, no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | epic A1–A7 + ## Architecture |
| 70 | Tests | done | remote.test.sh 95 (moved RC/RF/LC/AR, RC9b, LC10, FC14/15 + CT1); external.test.sh CT1, MV1, MV2 seen red first, FC15 seen red |
| 80 | Subtasks | skipped | one change |
| 90 | Implementation | done | ## Implementation |
| 100 | Tech Debt | done | none new: lib.sh helpers copied by design (root CLAUDE.md, Plugin Independence) |
| 110 | Reflection | done | root CLAUDE.md (tree, table, trigger vocabulary), both plugin CLAUDE.md, READMEs |

## Description

Create the `remote-docs` plugin and move every remote-provider part of docs-manager into it: remote cards
(`*.gdrive.md`, `*.artifact.md` from PLUG-141), `.source.md`, `external remote`, `remote-diff`, `remote-stamp`, `remote-gone`,
`copy-stamp`, local copies, the how-to section *Remote documents*, the RC*/RF*/LC* tests, the trigger
phrases. Behaviour unchanged: a pure move. Starts after docs-manager 1.13.0 (PLUG-140, PLUG-141) is committed.

docs-manager keeps listing `*.<provider>.md` cards with ☁ by file name (data, no code shared) and stops
validating them; its `check` may say remote cards are present and validated by remote-docs.

## Acceptance criteria

- Both suites green on host and container; each plugin's suite passes copied out alone (no sibling).
- An existing project with `.gdrive.md` cards: docs-manager indexes them as before; remote-docs checks them
  with the same results docs-manager gave before the move.
- marketplace.json, both plugin.json, root README and CLAUDE.md (plugin table, trigger vocabulary) updated;
  `scripts/check-descriptions.sh` passes.
- The helpers remote-docs needs from docs-manager's lib.sh are copied, and each plugin has a test pinning
  the card fields it reads (the shared contract).

## Requirements

The acceptance criteria above, plus (user, 2026-11-16): **no version bump** in this task. docs-manager
stays at 1.12.1 until the release; the 2.0.0 bump the removed commands call for happens then. The new
plugin gets its first version in its own plugin.json and marketplace entry, since a plugin cannot exist
without one.

## Architecture

- `remote-docs/scripts/remote.sh`: the CLI, holding every moved function. Commands keep their behaviour
  and lose the `external` prefix: `status|check|list [root]`, `stamp <card> <time>` (was remote-stamp),
  `gone <card>` (remote-gone), `copy-stamp <card> <time>`, `diff <dir> <listing>` (remote-diff). Messages
  name the new commands. `DM_KEEP_IGNORED` becomes `RD_KEEP_IGNORED`.
- `remote-docs/scripts/lib.sh`: verbatim copies of `docs_find`, `drop_git_ignored`, `AWK_FM_COMMENT`,
  `fm_parse`, `fm_field`, `fm_list`, `fm_set` and whatever they call; nothing else.
- docs-manager keeps `REMOTE_PROVIDERS`, `remote_provider`, `is_remote_card`, `is_remote_copy`,
  `list_remote_cards` (index ☁, `list_docs`, `links`). `external status/check` drop the remote and copy
  states; `check` prints `REMOTE CARDS: N (validated by the remote-docs plugin)` without failing. The old
  subcommands answer `moved to the remote-docs plugin: remote.sh <new>` and exit 2. `DM_KEEP_IGNORED`
  goes (no user left).
- Tests: RC4/5/7/8, RF*, LC2–11, AR2–5 move to `remote-docs/scripts/test/remote.test.sh` with only the
  command names changed; RC1/2/6, LC1, AR1 (index, links) stay. A contract case in each suite pins the
  card names and fields it reads.

## Implementation (2026-11-16)

- `remote-docs/` created: `remote.sh` (status, check, list, stamp, gone, copy-stamp, diff), `lib.sh`
  (copied helpers, `RD_KEEP_IGNORED`), suite, SKILL.md, `how-to-remote-docs.md` (the moved *Remote
  documents* section, commands renamed, plus a short card-format section, since docs-manager's is no
  longer beside it), CLAUDE.md (moved invariants + the contract), README, plugin.json 1.0.0.
- docs-manager: classifier only, `REMOTE CARDS: N` line in `check`, old subcommands exit 2 naming the
  new one, `DM_KEEP_IGNORED` gone; how-to, SKILL, CLAUDE.md, README and keywords trimmed. Version kept
  at 1.12.1 (Requirements).
- Found on the way: the git-only cases RC9b and LC10 lived in `docs.test.sh` (skipped in the container,
  so first seen on the host) and moved too; FC14/FC15 read the `.source.md` example from the how-to and
  moved with it.
- Found on the way: PLUG-141's R9 (an artifact is never where a decision lives) had not reached the
  how-to. Added to the artifact section of `how-to-remote-docs.md`.

## Current State

Implementation complete and verified (2026-11-16): docs-manager 4 suites and remote-docs suite green on
host, `bash:5`, `bash:5` + git, no HOME (remote-docs also read-only HOME), and each plugin copied out
alone; `check-descriptions.sh` ok. Committed and pushed as e4f7c7b (no version bump). Completed 2026-11-16. Next in the epic: PLUG-145.
