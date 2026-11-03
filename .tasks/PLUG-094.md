---
title: "kickoff: gaps.sh reports phantom F12 tools"
status: completed
type: bugfix
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Context | done | read gaps.sh, questionnaire §F, settled.awk rows |
| 2 | Tests | done | existing.test.sh 10a/10b written first |
| 3 | Implementation | done | gaps.sh F12 branch |
| 4 | Reflection | done | format stated in questionnaire.md; no kickoff/CLAUDE.md change needed |

## Description

`gaps.sh` checks each F12 tool by splitting the F12 answer on commas and taking the **first word** of each piece
(`tr ',' '\n' | sed 's/[[:space:]].*$//'`). But F12 is a multi-select answer, recorded one `F12:` line per check, and
the natural line is `<check> → <tool>` (the questionnaire's own `→ tool` notation). So the "tool" looked up is the
check's first word, and a comma inside a tool description starts another phantom tool.

Example answer lines and what gaps.sh reports:

- `F12: Unit → Vitest` → "Unit is not set up" (should look for Vitest)
- `F12: Verdict accuracy → Vitest eval suite (test:eval) on fixture pages, calling the LLM; reports only`
  → "Verdict is not set up" and "calling is not set up"
- `F12: One local command → scripts/dev.sh test (also up, down, sh)` → "One", "down", "sh)" not set up

## Acceptance criteria

- The F12 answer format is stated once (questionnaire §F12 or the skill), and `answer.sh`/`plan.sh` examples follow it.
- `gaps.sh` takes the tool from the part after `→` (falling back to the whole value without one), and does not split
  inside a tool description.
- A test with the three example lines above reports only real missing tools.

## Implementation

- Test first (`kickoff/scripts/test/existing.test.sh`, 10a/10b, the three example lines plus a really missing `Lint → Biome`): seen red, with the six phantom tools (Unit, Verdict, calling, One, down, sh)).
- Fix in `kickoff/scripts/gaps.sh`: the tool is the first word after `→`, matched as a literal string by bash `${v#*→}` (no awk offsets, so no multibyte trap); without an arrow the value is split at commas (a list such as inspect.sh proposes). A tool that is an existing project path (`scripts/dev.sh`) counts as set up.
- Format stated once: `questionnaire.md`, after "Tools are named as soon as the stack is known". Test 8d now records F12 in that format.
- Defect reintroduced once (comma split of the whole value): 10a and 10b went red again; restored.
- Host `all.sh` and `bash:5` container `all.sh`: all green (72 in existing, 0 failed).
- Not done: inspect.sh still proposes F12 as one comma list (`jest, eslint`, test 6c); gaps.sh handles it through the no-arrow fallback.

## Current State

Implemented and tested on host and container; awaiting review and release (no version bump made).
