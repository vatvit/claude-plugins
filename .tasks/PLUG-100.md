---
title: "kickoff: inspect.sh proposes F12 as one check → tool line per tool"
status: completed
type: bugfix
priority: low
tags: ["kickoff-plugin"]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Context | done | below |
| 2 | Requirements | done | = Acceptance; check names from the questionnaire checks table |
| 7 | Tests | done | 6c, 6c2, 10c red first; 6l/6m rescoped; 2 mutants caught |
| 9 | Implementation | done | kickoff 0.10.2 |
| 11 | Reflection | done | kickoff/CLAUDE.md, SKILL.md |

## Problem

PLUG-094 stated the F12 answer format once (one `F12: <check> → <tool> [description]` line per check) and made
`gaps.sh` read it. `inspect.sh` (through `infer.awk`) still proposes F12 for an existing project as one comma list
(`jest, eslint`), so a proposed answer does not follow the format. `gaps.sh` keeps a comma-split fallback only for
this case.

## Acceptance

- `inspect.sh` proposes one F12 line per detected tool, in the `<check> → <tool>` form, with the check named from
  what was detected (unit tests, lint, …) and its evidence as today.
- Test 6c changes to the new form; a test shows `gaps.sh` reports no phantom tool for the proposed answer.
- Once nothing writes the comma form, decide whether `gaps.sh` keeps its comma fallback (old recorded answers).

## Context

- `inspect.sh` gathered tools from the manifests into one comma list and hinted `F12` once; `infer.awk` keeps the
  first hint per id (CLAUDE.md "one hint per question", tests 6l/6m), so several F12 rows needed an explicit
  exception, not a second hint.
- Check names exist only in the questionnaire's checks table (Unit, E2E success path, Formatter / code style,
  Linter / static analysis, Type checks); no awk parses that table.
- `answer.sh --add` already records list answers one line per value.

## Implementation

- `inspect.sh`: `add_tools` hints `F12+ "<check> → <tool>"` per tool, evidence its manifest; `check_of` maps a tool
  to the check it serves (default Unit).
- `infer.awk`: an id ending in `+` is one line of a list answer, proposed as written, every distinct line kept.
- `gaps.sh` keeps the comma fallback: answers recorded from kickoff ≤ 0.10.1 proposals are still read. Decision.
- SKILL.md: record the first F12 row, `--add` the rest. kickoff/CLAUDE.md: the list exception to "one hint".
- Tests: 6c/6c2 (the rows and their evidence), 10c (recorded as proposed: 2 lines, no F12 gap), 6l/6m now
  "one row per question except the list F12" and count distinct ids. Mutants: old infer.awk (5 red), eslint
  mapped to Unit (6c red).

## Current State

Completed in kickoff 0.10.2. All kickoff suites green on the host and in bash:5.
