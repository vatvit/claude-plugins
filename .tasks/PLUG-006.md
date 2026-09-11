---
title: Config conventions across plugins (shared reader direction ruled out)
status: completed
type: refactor
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Requirements | done | See ## AMENDED — 3 surviving items |
| 20 | Assessment | done | Verified: json_str dup + precedence logic implemented twice; zero tests |
| 30 | POC | skipped | Known refactor; docs-manager lib.sh is the proven pattern |
| 40 | Domain | skipped | No new vocabulary |
| 50 | Architecture | done | Mirror docs-manager: plugin-local lib.sh, sourced not forked |
| 60 | Tests | done | No-regression harness first — task-roadmap has none |
| 70 | Subtasks | skipped | Single small refactor |
| 80 | Implementation | done | Found + fixed a shipped set -e bug; one precedence impl; 20 new tests |
| 90 | Tech Debt | done | none deferred; audit found + fixed the empty-tasks-dir crash |
| 100 | Reflection | done | independence + config conventions in repo CLAUDE.md; plugin CLAUDE.md created |

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

## Implementation

Delivered — and the harness written to make the refactor safe found a **live bug in
shipped task-roadmap 1.0.1** before a single line was refactored.

### The bug

`generate.sh` runs under `set -euo pipefail`. `json_str` is `grep | head | sed`, and
**grep exits non-zero when it matches nothing** — with `pipefail` that status
propagates out of `v="$(json_str title "$CFG")"` and kills the script.

Effect: **any `.task-roadmap.json` missing *any* key aborted generation.** A config
containing only `tasksDir` — a perfectly reasonable config, and the shape the README
implies — made the tool exit 1 with no output.

It survived a release for two reasons:
1. the plugin had **zero tests**;
2. the one config read that worked (`.task-config.json`) happens to sit inside an `&&`
   list, where `set -e` is suppressed. So the feature appeared to work, and only the
   plugin's *own* config file was broken.

Five of the twenty new assertions failed against shipped code. All pass now.

This is the third instance this session of the same shape — a helper whose empty
result is normal returning non-zero under `set -e`. It is now written into the repo
CLAUDE.md as a named trap rather than a lesson three tasks had to relearn.

### The duplication, as re-scoped

- `json_str` existed in `generate.sh` and inline in `regenerate-hook.sh`.
- Worse, **the config-precedence rule was implemented twice, differently**: generate.sh
  read `.task-config.json` then let `.task-roadmap.json` overwrite; the hook looped both
  and broke on the first hit. They agreed only by coincidence, and nothing would have
  caught them drifting. Now one `resolve_tasks_dir`, with cases 4 and 7 pinning that
  generator and hook resolve identically.

### Files

| File | Change |
|---|---|
| `task-roadmap/scripts/lib.sh` | NEW — `json_str`, `json_str_array`, `resolve_tasks_dir` |
| `task-roadmap/scripts/generate.sh` | sources lib.sh; config block collapsed; bug fixed |
| `task-roadmap/scripts/regenerate-hook.sh` | sources lib.sh; 8 lines of duplicated precedence logic → 1 |
| `task-roadmap/scripts/test/roadmap.test.sh` | NEW — 20 assertions, first tests this plugin has had |
| `task-roadmap/CLAUDE.md` | NEW — plugin had none; documents lib.sh, the trap, testing |
| `task-roadmap/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | 1.0.1 → 1.0.2 |
| repo `CLAUDE.md` | **Plugin Independence** section + **Config convention** |

### On items 2 and 3 of the re-scope

- **Documented the config convention** — flat JSON at project root, named for the
  plugin, every key optional with a default, plus the `set -e`/`grep` trap.
- **`task-roadmap` reading `tasksDir` from `.task-config.json` is documented as
  intended**, not changed: shared *data* degrading to a default is allowed under the
  independence rule; shared *code* is not.

### Verified

- 20/20 on host, `bash:5` container, and a standalone copy of the plugin directory
- docs-manager still 85/85 — untouched, as required
- this repo's own roadmap regenerates: `wrote .tasks/roadmap.html (6 tasks)`

## Tech Debt

None deferred. The tech-debt review ran the same `set -e` audit as PLUG-005 across
task-roadmap and found **one more defect, fixed here**:

- **An empty tasks directory crashed with an awk error.** `[ -d "$TASKS_DIR" ]` passed,
  then the `"$TASKS_DIR"/*.md` glob stayed literal and awk reported
  `can't open file .../tasks/*.md`, exit 2. "Nothing planned yet" is a normal state and
  now gets a clear message: `no task files in <dir> — nothing to chart`. Cases 2b–2d.

Checked and **left alone**, correctly:
- `regenerate-hook.sh:14`'s grep pipeline — the hook has no `set -e`, so a no-match is
  harmless there, and the hook must exit 0 regardless.
- `generate.sh:103`'s `grep -o '"id":' | wc -l` — unreachable with zero tasks now that
  the guard above rejects an empty dir first.

**Carried forward:** nothing. This was the last open task.

## Reflection

**Repo `CLAUDE.md`** gained two sections: **Plugin Independence** (the rule, why
cross-plugin DRY is wrong, shared data vs shared code, and the standalone-copy proof)
and **Config convention** (flat JSON named for the plugin, every key optional, plus the
`set -e`/`grep` trap that caused the shipped bug).

**`task-roadmap/CLAUDE.md`** created — the plugin had none, so nothing would have told
the next session that a test harness now exists or why `json_str` ends in `|| true`.

**Both manifests** bumped to 1.0.2, following the "Changing an Existing Plugin" rule
written one task earlier. First use of that checklist; it worked.

**Lessons worth keeping:**
- **Write the no-regression harness before the refactor, even when the refactor looks
  cosmetic.** This task was scoped as "collapse a duplicated one-liner". The harness
  found a bug that made the plugin's own config file unusable, and it had shipped in
  1.0.1. Five of twenty assertions failed against released code.
- **The same bug class appeared four times in one session** (`docs-manager` twice,
  `task-roadmap` twice): a helper whose empty result is normal returning non-zero under
  `set -e`. After the second occurrence it should have gone into the repo CLAUDE.md
  immediately rather than after the fourth. Recurring bug shapes are cheaper to write
  down than to re-derive.
- **Duplicated *logic* is worse than duplicated *code*.** The `json_str` copy was
  harmless; the config-precedence rule implemented twice in two different shapes was
  the real risk, and it was invisible until the tests forced both paths to be stated.
