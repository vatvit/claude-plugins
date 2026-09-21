---
title: docs-manager scripts use a hardcoded #!/bin/bash shebang
status: completed
type: bugfix
priority: low
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | 6 files, not 3 — task-roadmap's test runner too; both hooks already use `bash x.sh`, so latent confirmed |
| 20 | Requirements | skipped | Task's own acceptance criteria are already the spec |
| 30 | Assessment | done | One-line change per file; no logic touched |
| 40 | POC | skipped | Nothing unknown |
| 50 | Domain | skipped | No domain surface |
| 60 | Architecture | done | Scope widened to task-roadmap; guard duplicated per plugin, not shared — see ## Architecture |
| 70 | Tests | done | One case per plugin, self-excluding scan; proven by canary |
| 80 | Subtasks | skipped | One slice |
| 90 | Implementation | done | 6 shebangs + 2 test cases + 2 patch version bumps |
| 100 | Tech Debt | done | None raised; see ## Tech Debt |
| 110 | Reflection | done | CLAUDE.md rule already existed from PLUG-008; nothing to add |

## Description

`docs-manager/scripts/{diagram.sh,docs.sh,lib.sh}` start with `#!/bin/bash`. On Alpine — the
`bash:5` image this repo's dual-target convention uses — bash lives at `/usr/local/bin/bash`
and `/bin/bash` does not exist, so anything that *execs* those scripts directly dies with
`bad interpreter: No such file or directory`.

Raised by PLUG-008, where exactly this broke the task plugin in the container: `allocate-id.sh`
execs `resolve-config.sh` rather than running `bash resolve-config.sh`, so the shebang fired.
Eight test cases failed on Alpine while all passed on macOS.

## Why it is latent rather than broken

docs-manager's own suite invokes its scripts as `bash scripts/docs.sh …`, which ignores the
shebang entirely — so the bug is invisible today. It becomes real the moment any script,
hook or user runs one of them as an executable. `task-roadmap` already uses the `env` form;
docs-manager is the only plugin left on the hardcoded path.

## Scope

- Change the three shebangs to `#!/usr/bin/env bash`.
- Add a case to docs-manager's suite asserting no `#!/bin/bash` remains, matching the one
  added to `task/scripts/test/port.test.sh`.
- Verify on both targets.

## Acceptance criteria

- No `#!/bin/bash` anywhere in `docs-manager/`.
- docs-manager's suite passes on the host and in `bash:5`.
- A test fails if the hardcoded form is reintroduced.

## Notes

The repo `CLAUDE.md` Shell Conventions section already gained the rule during PLUG-008 —
this task is the remaining cleanup, not the decision.

## Context

The task named three files. There were **six**, across two plugins:

```
docs-manager/hooks/diagram-watch-hook.sh
docs-manager/scripts/lib.sh
docs-manager/scripts/docs.sh
docs-manager/scripts/diagram.sh
docs-manager/scripts/test/diagram.test.sh
task-roadmap/scripts/test/roadmap.test.sh
```

Two corrections to the task as written:

- **docs-manager had five, not three.** The hook and the suite's own runner were missed.
- **"task-roadmap already uses the `env` form; docs-manager is the only plugin left" was wrong.**
  `task-roadmap/scripts/test/roadmap.test.sh` still carried the hardcoded form.

`task/` (9 files) and `session-storage/` (3) were already clean.

**Latency confirmed, not assumed.** Both plugins' `hooks.json` invoke their hook as
`bash ${CLAUDE_PLUGIN_ROOT}/…`, which ignores the shebang entirely, and all six files are
mode 644 — so nothing on either plugin's current path could ever have fired it. The fix is
defensive: it costs nothing and removes the trap before someone `chmod +x`es a script or
execs one from another.

The `#!/bin/sh` occurrences are correct and were left alone: three in `docs-manager/README.md`
are documentation recipes, two inside `diagram.test.sh` are heredoc fixtures writing a fake
renderer. `/bin/sh` exists on every target.

## Architecture

- **Scope widened to `task-roadmap`.** Same one-character defect; closing a task about removing
  hardcoded shebangs while leaving one in the repo would defeat the point. Recorded here rather
  than silently — the task title still says docs-manager.
- **The guard is duplicated, one case per plugin, not shared.** Per *Plugin Independence* a
  plugin never sources a sibling's file and must pass its suite standalone, so `docs-manager`
  and `task-roadmap` each carry their own copy. This is the correct outcome, not debt.
- **The scan excludes its own file.** Learned from PLUG-008: a test that greps for a forbidden
  string necessarily contains it, and without the exclusion it reports itself as the violation.
- **Patch bumps, not minor.** No user-visible capability changed, so `docs-manager` 1.3.0 →
  1.3.1 and `task-roadmap` 1.0.2 → 1.0.3, synced into `marketplace.json`. Descriptions,
  keywords and skill trigger phrases are untouched — nothing about what either plugin does
  has changed.

## Tests

One case per plugin, both dual-target:

- `docs-manager/scripts/test/diagram.test.sh` — case 28, under a new `== packaging ==` section
- `task-roadmap/scripts/test/roadmap.test.sh` — case 10, same

Each greps its own plugin root for `^#!/bin/bash`, excludes the test file itself by absolute
path, and asserts the result is empty — reporting the offending paths when it is not.

**Results:** docs-manager 91/91, task-roadmap 24/24 — green on the host *and* in `bash:5`.

**The guard was proven, not assumed.** Dropping a canary file containing `#!/bin/bash` into
`docs-manager/scripts/` turned the suite red with the offending path named
(`FAIL 28 … actual: [scripts/.plug011-canary.sh]`, 90 passed / 1 failed); removing it restored
91/91. A regression test that has never been seen to fail is not evidence of anything.

## Tech Debt

None raised. Two observations, neither worth a ticket:

- The six files are mode 644, so they cannot be exec'd today regardless of shebang. Making the
  entry-point scripts executable would be a deliberate interface change, not a fix, and nothing
  currently needs it.
- `task/scripts/test/port.test.sh` asserts its scripts *are* executable; docs-manager and
  task-roadmap do not. The inconsistency is harmless while every caller uses `bash x.sh`.

## Reflection

Nothing new to record. The repo `CLAUDE.md` Shell Conventions rule — `env`-form shebang, plus
*why* it hides (only `exec` triggers it) — was added by PLUG-008 and is already correct. This
task was the cleanup that rule implied.

The one transferable point, and it is PLUG-008's rather than this task's: **a bug found in one
plugin should be grepped for across all of them in the same pass.** PLUG-008 raised this ticket
for docs-manager after finding the defect in `task`, but scoped it from memory rather than from
a scan — which is how three files became six and how a second plugin went unnoticed.

## Current State

**Build status:** complete and green. docs-manager 91/91, task-roadmap 24/24, both on host and
in `bash:5`. Guard verified to fail on reintroduction.

**Changed:** 6 shebangs, 2 new test cases, `docs-manager` 1.3.0 → 1.3.1, `task-roadmap`
1.0.2 → 1.0.3, `marketplace.json` synced.

**Known issues:** none.

**Not committed.** Working tree carries all of the above.
