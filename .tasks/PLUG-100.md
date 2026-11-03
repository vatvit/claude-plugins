---
title: "kickoff: inspect.sh proposes F12 as one check → tool line per tool"
status: proposed
type: bugfix
priority: low
tags: [kickoff]
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Context | — | |
| 2 | Requirements | — | |
| 7 | Tests | — | |
| 9 | Implementation | — | |
| 11 | Reflection | — | |

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
