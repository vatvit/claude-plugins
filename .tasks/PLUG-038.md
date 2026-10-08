---
title: kickoff — per-account defaults (kickoff.json)
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

`${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json` overrides the questionnaire's ★ defaults for one account.
For example, a work account defaults to "employer's project" and "tasks outside the repo".

Spec: `kickoff/skills/kickoff/references/questionnaire.md` (agreed 2026-10-08). Epic: PLUG-034.

## Acceptance criteria

- Every key is optional, and an absent file or key falls back to the ★ default. Watch the
  `pipefail` trap noted in the repo CLAUDE.md.
- Two accounts with different `CLAUDE_CONFIG_DIR` values get their own defaults. A test proves it.
- The defaults that depend on earlier answers (A3, A4) still apply where the file says nothing.

## Dependencies

PLUG-035.

## Context

`lib.sh` already passed a user-layer file into the model as `defaults_tsv` (a stub since PLUG-035), and `default_of()` in lib.awk already put `udef` first. The repo CLAUDE.md "Per account or per machine" rule puts this file per account. There is a pipefail trap for configs missing keys (repo CLAUDE.md, Config convention).

## Architecture

- `${CLAUDE_CONFIG_DIR:-~/.claude}/kickoff.json` is a flat JSON object of question ids → strings, decoded by `defaults_tsv` (escapes `\"` and `\\`). Keys that are not ids are ignored. Ids that are not questions are reported on stderr by `plan.sh` and are not fatal.
- `defaults.sh list | set | unset`: validated ids, one-line values, diff-guarded writes, sorted.
- Precedence: answer > user default > `(★ if …)` > ★.
- **Found while testing:** busybox awk dropped a backslash in a `gsub` replacement where gawk and BSD awk doubled it. JSON escaping is now `json_q()` in `json.awk`, a character loop shared by `defaults-write.awk` and `registry-insert.awk`. The scaffold's registry writer had the same latent bug and is fixed too (its program moved out of the shell script).

## Tests

`scripts/test/defaults.test.sh`, 18 checks, green on the host and in `bash:5`. **Shown failing:** ignoring `CLAUDE_CONFIG_DIR` fails 3b and 3c; ignoring the user layer fails 1c, 2b, 3a, 4a and 4e.

## Implementation

- `defaults.sh`, `json.awk`, `defaults-write.awk`, `registry-insert.awk`; the user layer in `lib.sh`; the unknown-id warning in `plan.awk`.
- SKILL: offer `defaults.sh set` when a default is changed for good.
- README and CLAUDE.md updated. 0.3.0 → 0.4.0.

## Tech Debt

None.

## Reflection

The repo CLAUDE.md awk traps now include the gsub backslash. Precedence and the json_q rule are in kickoff/CLAUDE.md.

## Current State

Completed. Next: PLUG-039 (existing-project mode).
