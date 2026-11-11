---
title: "task — a .task-config.json written on one line is misread (tasksDir swallows the whole line)"
status: completed
type: bugfix
priority: low
created: 2026-11-11 18:41
tags: ["task-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | resolve-config.sh had two copies of a line-based awk extractor; allocate-id.sh had two line-based nextId writers |
| 30 | Assessment | done | the global writer had the same bug: in a one-line registry it rewrote the first project's nextId |
| 60 | Architecture | done | one JSON awk library in lib.sh (_TASK_JSON_AWK) behind task_config_read, task_config_set_num, task_config_edit |
| 70 | Tests | done | config-layout.test.sh 18 cases, 16 red first |
| 90 | Implementation | done | every suite green: host, task-test container, standalone |
| 100 | Tech Debt | done | fixed in passing: task_config_edit escaped with gsub (busybox backslash trap) and had its own pair regex |
| 110 | Reflection | done | configuration.md (any layout, in-place nextId), task/CLAUDE.md |

## Description

Found while probing PLUG-118 (2026-11-11). `resolve-config.sh` parses the project config one key per line (awk, around lines 30-50).
A valid JSON object on a single line, `{"tasksDir":".tasks","prefix":"T","nextId":1}`, gives
`tasksDir=<dir>/.tasks","prefix":"T","nextId`, and `allocate-id.sh` then fails with `ERROR: config missing tasksDir/prefix`.
The multi-line form, the one the skill writes, works. Check whether the other scripts that write `nextId` back assume one key per line too.

Fix options: accept any JSON layout (tokenise on `,` and `{}` outside strings), or document one key per line as required and fail
with that message instead of a wrong value. Reproduce with a failing test first.

## Implementation (2026-11-11)

- Chose "accept any JSON layout" over "require one key per line". Both config files are flat objects of scalars (the registry one level deeper), so a small pair scanner over the whole file is enough.
- `lib.sh` `_TASK_JSON_AWK` holds the awk functions `json_scope` (the whole file, or the object under the project's key, skipping a value that merely equals the path), `json_pairs`, `json_decode` and `json_quote`. Escapes go through a character loop, never gsub.
  - `task_config_read <file> [<project>]` serves both readers in `resolve-config.sh` (local, and `lookup_global`), which replaces the two copied extractors the PLUG-118 note asked to unify.
  - `task_config_set_num <file> <key> <n> [<project>]` replaces the two line-based nextId writers in `allocate-id.sh`. It rewrites only the number and keeps every other byte.
  - `task_config_edit` now uses `json_pairs` and `json_quote` instead of its own regex and a gsub escape.
- Tests are in a new suite (`config-layout.test.sh`), so `config.test.sh` stays untouched: it still carries PLUG-118's uncommitted cases.

## Current State

Completed 2026-11-11. Not committed. config-layout 18/18, and every task suite is green on host, container and standalone.

## Note 2026-11-11 (from PLUG-118)

`resolve-config.sh` has two copies of the key/value awk extraction: one for the local config (around lines 32-51) and one inside
`lookup_global` (around lines 91-108). Fix the one-line bug in a single shared awk function used by both, not twice.
