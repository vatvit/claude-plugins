---
title: kickoff — ask about backward compatibility, explicitly
status: proposed
type: feature
epic: kickoff-next
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | — | |
| 20 | Requirements | — | |
| 30 | Assessment | — | |
| 40 | POC | — | |
| 50 | Domain | — | |
| 60 | Architecture | — | |
| 70 | Tests | — | |
| 80 | Subtasks | — | |
| 90 | Implementation | — | |
| 100 | Tech Debt | — | |
| 110 | Reflection | — | |
## Description

Backward compatibility matters, but **only when it makes sense**. A PoC that keeps compatibility shims,
deprecation paths and data migrations pays for consumers it does not have. A library that breaks its
callers silently loses them. Today kickoff never asks about it, so every session guesses.

Add one question that is **always asked explicitly**. When does backward compatibility start to apply?
From the very beginning, later (from a named trigger), or never?

## Requirements (negotiable)

- New questionnaire row, asked `always`. Likely section C (Scope) or B. Settle the place at Architecture.
  Proposed options (at most 4):
  - *Not needed yet — no consumers; change interfaces, formats and data freely* (★ if A3 = PoC)
  - *From the start* (★ if A3 = Library)
  - *Later — from a trigger* (free text: first release, first client, v1, …)
  - *Never — always free to break*
- **Never settled by "accept all defaults".** The user said to ask explicitly. The recommended option is
  shown first, but the user picks it. This may need a small marker in the table grammar
  (§Reading the tables) and in `lib.awk`/`plan.awk`. Decide at Architecture whether "no plain ★" is
  enough, since C1 already has only a conditional ★.
- `<ID>.why` is captured as usual.
- **Goes to:** `charter decision`, plus a CLAUDE.md line that turns the answer into an instruction:
  - not needed yet / never → change freely: no shims, no deprecation paths, no migrations for old data;
  - from the start → keep compatibility: deprecate before removing, migrate stored data;
  - later → free to break until `<trigger>`, then the rule flips. The trigger also goes to the charter's
    *Open questions*, so it gets revisited.
- *Not decided yet* stays valid and goes to *Open questions*, like every question.

## Acceptance criteria

- `plan.sh --next` lists the question for every project kind, with the ★ that A3 implies.
- Accept-all for its section leaves it unanswered (it stays `ask`).
- The charter has the decision with its *why*. The generated CLAUDE.md has the matching instruction
  line for each answer. A *later* answer adds an open question naming the trigger.
- Tests go through the real `questionnaire.md`. No question text is copied into a fixture.

## Notes

- Also fix `questionnaire.md:31`, which says "Only *exceptions* to them are asked (E4)". Exceptions are
  **E5**. It is the same file, so it rides along.
- Files: `skills/kickoff/references/questionnaire.md`, `scripts/claude.awk`, maybe `lib.awk`/`plan.awk`,
  `scripts/test/kickoff.test.sh`. These are disjoint from PLUG-051/052, except `lib.awk` if the
  marker is needed.

## Current State

Proposed, backlog for the next kickoff release (epic PLUG-049). Not started.
