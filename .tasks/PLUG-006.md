---
title: Config conventions across plugins (shared reader direction ruled out)
status: proposed
type: refactor
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | — | |
| 20 | Assessment | — | |
| 30 | POC | — | |
| 40 | Domain | — | |
| 50 | Architecture | — | |
| 60 | Tests | — | |
| 70 | Subtasks | — | |
| 80 | Implementation | — | |
| 90 | Tech Debt | — | |
| 100 | Reflection | — | |

## Description

Tech debt raised during PLUG-001. Two overlapping duplications, both of which get
worse with every plugin added.

**1. The JSON reader is copy-pasted.** The same `grep -o '"key"...' | sed` idiom
exists in:

- `task-roadmap/scripts/generate.sh:28` (as `json_str`)
- `task-roadmap/scripts/regenerate-hook.sh` (inline, reading `tasksDir`)
- and would become a third copy in `docs-manager/scripts/docs.sh` when PLUG-002
  adds config reading.

**2. Config keys are spread across files and read by the wrong owners.**
`.task-config.json` carries `tasksDir`, and `task-roadmap` reads that file as a
fallback — so a task-skill config file is load-bearing for a different plugin. Add
`.task-roadmap.json` and a docs config and there are three files with overlapping
keys and no single place to look.

## Why it matters

This repo's top rule is DRY. Three copies of a parser and a key read by two unrelated
plugins is the exact shape the rule exists to prevent. It is cheap now (three call
sites) and expensive later.

## Proposed direction

- one `.claude-plugins.json` at project root, a section per plugin, with the existing
  per-plugin files still honoured as overrides during migration
- one shared reader script; each plugin sources it rather than reimplementing it
- decide where the shared script lives — a plugin cannot source another plugin's file
  by a stable path, so this may need a small vendored copy with a single upstream, or
  a `lib/` at repo root. **This is the open question of the task.**

## Constraints

- bash 3.2, BSD + GNU compatible (see repo CLAUDE.md)
- no runtime dependency, no `jq`
- must not break existing installs that already have `.task-config.json`

## Related

- PLUG-001 (raised it), PLUG-002 (would add the third copy)

## AMENDED — proposed direction ruled out (during PLUG-002)

The user set a hard constraint after this task was written: **plugins must be
independent and work in any combination.** A plugin ships as its own directory and
cannot assume a sibling is installed.

That kills the "one shared reader script; each plugin sources it" direction, and the
`lib/` at repo root with it. Both create a runtime dependency between plugins.

**The premise was also partly wrong.** DRY applies *within* a plugin, not across
plugins. Two plugins each carrying their own small JSON helper is the correct
outcome, not debt — so duplication #1 in the Description is mostly **not** a defect.

What remains genuinely worth fixing:

- **Duplication inside a single plugin.** `task-roadmap` has the `json_str` idiom in
  both `generate.sh` and `regenerate-hook.sh`. That one is real and fixable by a
  `lib.sh` inside `task-roadmap`, exactly as `docs-manager` now has.
- **A documented convention** for the config-file shape, so plugins agree on
  structure without sharing code.
- **`task-roadmap` reading `tasksDir` from `.task-config.json`** is acceptable under
  the constraint — reading shared config *data* is fine, since it degrades to a
  default when the file is absent. No change needed; document it as intended.

Re-scope to those three, or reject. Do **not** implement the original direction.
