---
title: kickoff — existing-project mode (A0)
status: completed
type: feature
epic: kickoff
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done | |
| 20 | Requirements | done | |
| 30 | Assessment | done | |
| 40 | Architecture | done | |
| 50 | Tests | done | |
| 60 | Implementation | done | |
| 70 | Tech Debt | done | |
| 80 | Reflection | done | |

## Goal

When kickoff runs on a project that already has code or a partial setup, it reads what is there, infers
the answers it can (and shows them for confirmation), and asks only about the gaps. The same mode lets
the older projects be brought up to date later.

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034. (question A0)

## Acceptance criteria

- On a fully set-up project it asks nothing and changes nothing.
- An inferred answer is never written without the user confirming it.
- Existing files are never overwritten blindly: a differing file is shown as a diff and needs approval.

## Dependencies

PLUG-035 and PLUG-036.

## Context

- PLUG-035/036 already made every generator idempotent: seeded files are written once, and the charter and CLAUDE.md are refused once edited.
- So "a fully set-up project is asked nothing and changed in nothing" holds for a project kicked off before, as long as no file gets rewritten. What was missing: inferring answers for a project set up *without* kickoff, and showing a refused file's change.
- Real fixtures read, read-only: sample-poc (root `./dev.sh`; `docker/compose.yml` with 1 default service and 4 behind `profiles:`; `${APP_PORT:-8310}`) and project-c (`develop` branch, `.task-config.json`, a roadmap).

## Architecture

- **`inspect.sh`** proposes `id · answer · evidence` rows for unanswered questions and writes nothing. It reads files only (`.git/config`, refs and packed-refs, `.task-config.json`, the task registry, compose, `scripts/dev.sh` or `./dev.sh` or Makefile, the docs folders), so it needs no git binary.
- **`infer.awk`** resolves each hint to the questionnaire's own option text, so no option wording lives in the shell script.
- **Compose:** only services that start by default count toward I2. Services behind `profiles:` are test runners and tools.
- **`--diff`:** `scaffold.sh --diff` is a full dry run that shows the change to CLAUDE.md, and `charter.sh --diff` does the same for the charter. `scaffold.sh --force` replaces an edited CLAUDE.md once the user agrees.
- SKILL step 0: on an existing project, inspect first, then show the proposals with their evidence. Only confirmed answers are recorded.
- **Found:** on the host, `starts_ci` aborted with "illegal byte sequence" whenever a prefix cut through `—`. macOS awk's `substr` works in bytes but its `tolower` validates UTF-8. It now lowercases whole strings and compares with `index`. This was latent since PLUG-035; it showed up the first time a hint was matched against a multibyte option. Also: enclosing quotes are now stripped from an option used as a sentence (B1).

## Tests

`scripts/test/existing.test.sh`, 31 checks, green on the host and in `bash:5`. The whole plugin passes 172 checks on each target, and from a standalone copy. **Shown failing:**
- with the old `starts_ci`, 10 checks fail on the host (2c–2j, 3b, 4b);
- when inference ignores answers, 2m fails;
- when `--diff` writes, 5a and 5b fail.

## Implementation

- `inspect.sh`, `infer.awk`; `--diff` / `--force` in scaffold.sh and `--diff` in charter.sh.
- SKILL step 0 and the refusal handling. README, CLAUDE.md, and the repo CLAUDE.md awk traps.
- 0.4.0 → 0.5.0.

## Tech Debt

None.

## Reflection

The repo CLAUDE.md awk traps gain the macOS `tolower(substr())` case. kickoff/CLAUDE.md gains "inspect.sh proposes, never records" and the `starts_ci` note.

## Current State

Completed. Epic PLUG-034's five sub-tasks are all done.
