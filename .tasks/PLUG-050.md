---
title: kickoff — ask about backward compatibility, explicitly
status: completed
type: feature
epic: kickoff-next
priority: medium
---

## Workflow

| # | Step | Status | Notes |
|---|------|--------|-------|
| 10 | Context | done |  |
| 20 | Requirements | done | below; settled at Architecture |
| 30 | Assessment | done | lib.awk/plan.awk/claude.awk/charter.awk |
| 40 | POC | skipped | no unknowns |
| 50 | Domain | skipped | no domain model |
| 60 | Architecture | done | C5 in section C; Ask-when keyword explicitly → state explicit |
| 70 | Tests | done | kickoff.test.sh 9a–9i, seen red |
| 80 | Subtasks | skipped | small |
| 90 | Implementation | done |  |
| 100 | Tech Debt | done | none |
| 110 | Reflection | done | kickoff/CLAUDE.md |
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

## Outcome (2026-10-17, kickoff 0.6.0)

- **C5** in section C: "When does backward compatibility start to apply?" — *Not needed yet* (★ if A3 = PoC),
  *From the start* (★ if A3 = Library), *Later — from a trigger*, *Never*. Goes to `charter decision, CLAUDE.md`.
- **Decision (Architecture):** "no plain ★" was not enough — for a PoC or a library the conditional ★
  resolves and accept-all would record it. So the grammar gains an *Ask when* keyword `explicitly`
  (always, never settled by a default), and lib.awk a state `explicit`; `--next` lists it with the
  recommendation in the value column. `to_ask()` in lib.awk is the one "still to be asked" test.
- A *Later* answer is recorded as `Later — from <trigger>`. `later_trigger()` (lib.awk, pattern-matched
  for multibyte safety) feeds both claude.awk (free to break until the trigger, then keep compatibility)
  and charter.awk (an open question "revisit at: <trigger>"), generically, not keyed on C5.
- CLAUDE.md lines share one "free" and one "keep" phrase. *Not decided yet* → Open questions, no line.
- Ride-alongs: questionnaire "(E4)" → "(E5)"; the outputs table names C5.
- Test helper `autofill` answers an explicit row only from an override, else fails. Tests 9a–9i;
  seen red before the code (15) and with the state removed / the trigger removed.

## Current State

Completed 2026-10-17. Host, `bash:5` container and a sibling-free copy: ALL GREEN.
